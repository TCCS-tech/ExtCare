require "csv"

source = Rails.root.join("_private/billing-category.csv")
abort "CSV file not found: #{source}" unless File.file?(source)

categories = {
  "AM & PM" => { prepaid_am: true, prepaid_pm: true },
  "PM only" => { prepaid_am: false, prepaid_pm: true }
}.freeze

normalize_name = ->(name) { name.to_s.strip.downcase.gsub(/\s+/, " ") }
students_by_name = Student.all.to_a.group_by do |student|
  [normalize_name.call(student.last_name), normalize_name.call(student.first_name)]
end

rows = CSV.read(source, headers: true, encoding: "bom|utf-8")
abort "CSV must include Student Name and Billing category columns." unless
  rows.headers.include?("Student Name") && rows.headers.include?("Billing category")

imports = []
problems = []
rows.each_with_index do |row, index|
  line = index + 2
  name = row["Student Name"].to_s.strip
  last_name, first_name = name.split(",", 2).map { |part| part.to_s.strip }
  flags = categories[row["Billing category"].to_s.strip]

  if last_name.blank? || first_name.blank?
    problems << "Line #{line}: invalid student name #{name.inspect}"
    next
  end
  unless flags
    problems << "Line #{line}: unknown billing category #{row["Billing category"].inspect} for #{name}"
    next
  end

  matches = students_by_name[[normalize_name.call(last_name), normalize_name.call(first_name)]] || []
  if matches.one?
    imports << [matches.first, flags]
  elsif matches.empty?
    problems << "Line #{line}: student not found: #{name}"
  else
    problems << "Line #{line}: ambiguous student name #{name} (student IDs: #{matches.map(&:id).join(", ")})"
  end
end

if problems.any?
  abort "No changes made. Resolve these CSV/database mismatches:\n#{problems.map { |problem| "- #{problem}" }.join("\n")}"
end

if imports.map { |student, _flags| student.id }.uniq.length != imports.length
  abort "No changes made. The CSV contains duplicate student names."
end

updated = 0
Student.transaction do
  Student.update_all(prepaid_am: false, prepaid_pm: false)

  imports.each do |student, flags|
    student.reload
    student.update!(flags)
    updated += 1
  end
end

require "rake"
Rails.application.load_tasks
Rake::Task["billing:recalculate_all"].invoke

puts "Processed #{imports.length} students; reset prepaid flags for all students and applied categories to #{updated} students."
