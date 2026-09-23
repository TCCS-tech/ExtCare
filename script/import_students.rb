require "csv"
require "set"

source = Rails.root.join("_private/students.csv")
abort "CSV file not found: #{source}" unless File.file?(source)

grades = {
  "Kindergarten" => 0,
  "1st" => 1,
  "2nd" => 2,
  "3rd" => 3,
  "4th" => 4,
  "5th" => 5,
  "6th" => 6
}.freeze

rows = CSV.read(source, headers: true, encoding: "bom|utf-8")
csv_student_ids = rows.filter_map { |row| row["student_id"].to_s.strip.presence }.to_set
csv_names = rows.group_by do |row|
  [row["first_name"].to_s.strip.downcase, row["last_name"].to_s.strip.downcase]
end

created = 0
updated = 0

Student.transaction do
  rows.each do |row|
    first_name = row["first_name"].to_s.strip
    last_name = row["last_name"].to_s.strip
    student_id = row["student_id"].to_s.strip.presence
    grade_level = row["grade"].to_s.strip
    grade = grades.fetch(grade_level) do
      raise "Unknown grade level #{grade_level.inspect} for #{first_name} #{last_name}"
    end

    student = if student_id
      Student.find_or_initialize_by(student_id: student_id)
    else
      Student.find_or_initialize_by(first_name: first_name, last_name: last_name)
    end
    was_new = student.new_record?
    notes = row["notes"].to_s

    student.assign_attributes(
      first_name: first_name,
      last_name: last_name,
      blackbaud_id: row["blackbaud_id"].to_s.strip.presence,
      grade: grade,
      staff: notes.include?("STAFF"),
      prepaid_am: notes.include?("Prepaid AM"),
      prepaid_pm: notes.include?("Prepaid PM")
    )
    student.save!

    if was_new
      created += 1
    else
      updated += 1
    end
  end
end

missing_from_csv = Student.ordered_by_name.reject do |student|
  student_id = student.student_id.to_s.strip.presence
  name = [student.first_name.downcase, student.last_name.downcase]

  if student_id
    csv_student_ids.include?(student_id) || (csv_names[name]&.one? && csv_names.key?(name))
  else
    csv_names.key?(name)
  end
end

puts "Imported #{created} students; updated #{updated}."
puts "Database records not found in CSV (#{missing_from_csv.length}):"
missing_from_csv.each do |student|
  puts "- ##{student.id}: #{student.full_name} (student_id: #{student.student_id.presence || 'none'})"
end
