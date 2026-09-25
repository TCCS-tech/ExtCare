require "date"
require "open3"
require "rexml/document"
require "rexml/xpath"

source = Rails.root.join("_private/September.xlsx")
abort "Workbook not found: #{source}" unless File.file?(source)

MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
PROGRESS_WIDTH = 30

def show_progress(label, current, total, state)
  total = [total, 1].max
  percent = (current * 100 / total).clamp(0, 100)
  return if percent < state[:last_percent] + 2 && current < total

  filled = percent * PROGRESS_WIDTH / 100
  bar = "[#{'='. * filled}#{' ' * (PROGRESS_WIDTH - filled)}]"
  $stderr.print("\r#{label} #{bar} %3d%% (%d/%d)" % [percent, current, total])
  $stderr.puts if current >= total
  state[:last_percent] = percent
end

def xlsx_xml(path, entry)
  stdout, stderr, status = Open3.capture3("unzip", "-p", path.to_s, entry)
  raise "Could not read #{entry} from workbook: #{stderr}" unless status.success?

  REXML::Document.new(stdout)
end

def column_number(cell_reference)
  letters = cell_reference[/\A[A-Z]+/]
  letters.each_char.reduce(0) { |number, letter| number * 26 + letter.ord - 64 }
end

def cell_value(cell, shared_strings)
  return nil unless cell

  if cell.attributes["t"] == "inlineStr"
    REXML::XPath.match(cell, ".//m:t", "m" => MAIN_NS).map(&:text).join
  else
    value = REXML::XPath.first(cell, "m:v", "m" => MAIN_NS)&.text
    return nil if value.nil?

    cell.attributes["t"] == "s" ? shared_strings.fetch(value.to_i) : value
  end
end

def time_parts(value)
  # Entries use 3:00 PM-style clock values without a colon: 300-341 means
  # 3:00 to 3:41 PM. Keep malformed or incomplete entries for review.
  match = value.match(/\A(\d{3,4})\s*-\s*(\d{3,4})(?:\s+\$0)?\z/)
  return unless match

  [match[1], match[2]].map do |clock|
    hour, minute = clock.length == 3 ? [clock[0].to_i, clock[1, 2].to_i] : [clock[0, 2].to_i, clock[2, 2].to_i]
    hour += 12 if hour < 12
    raise ArgumentError, "invalid clock time #{clock.inspect}" unless (12..23).cover?(hour) && (0..59).cover?(minute)

    [hour, minute]
  end
end

shared_doc = xlsx_xml(source, "xl/sharedStrings.xml")
shared_strings = REXML::XPath.match(shared_doc, "/m:sst/m:si", "m" => MAIN_NS).map do |item|
  REXML::XPath.match(item, ".//m:t", "m" => MAIN_NS).map(&:text).join
end

workbook = xlsx_xml(source, "xl/workbook.xml")
relationships = xlsx_xml(source, "xl/_rels/workbook.xml.rels")
targets = REXML::XPath.match(relationships, "/r:Relationships/r:Relationship", "r" => PKG_REL_NS)
  .to_h { |relationship| [relationship.attributes["Id"], relationship.attributes["Target"]] }
sheets = REXML::XPath.match(workbook, "/m:workbook/m:sheets/m:sheet", "m" => MAIN_NS)

students_by_name = Student.all.to_a.group_by do |student|
  [student.first_name.to_s.strip.downcase, student.last_name.to_s.strip.downcase]
end
staff = User.find_by(email: "staff@example.com")
abort "Missing staff@example.com; seed the database before importing." unless staff

records = []
problems = []
sheet_data = sheets.filter_map.with_index do |sheet, index|
  target = targets.fetch(sheet.attributes["r:id"])
  entry = target.start_with?("/") ? target.delete_prefix("/") : "xl/#{target}"
  sheet_doc = xlsx_xml(source, entry)
  rows = REXML::XPath.match(sheet_doc, "/m:worksheet/m:sheetData/m:row", "m" => MAIN_NS)
  show_progress("Reading workbook", index + 1, sheets.length, { last_percent: -2 })
  [sheet, rows] if rows.any?
end

parse_total = sheet_data.sum { |_sheet, rows| [rows.length - 1, 0].max }
parse_current = 0
parse_progress = { last_percent: -2 }
sheet_data.each do |sheet, rows|
  header = rows.first

  date_columns = {}
  REXML::XPath.match(header, "m:c", "m" => MAIN_NS).each do |cell|
    raw = cell_value(cell, shared_strings)
    next unless raw&.match?(/\A\d+(?:\.0+)?\z/)

    serial = raw.to_f
    next unless (40_000..60_000).cover?(serial)

    date_columns[column_number(cell.attributes["r"])] = Date.new(1899, 12, 30) + serial.to_i
  end

  rows.drop(1).each do |row|
    parse_current += 1
    show_progress("Reading attendance", parse_current, parse_total, parse_progress)
    cells = REXML::XPath.match(row, "m:c", "m" => MAIN_NS).to_h do |cell|
      [column_number(cell.attributes["r"]), cell]
    end
    last_name = cell_value(cells[1], shared_strings).to_s.strip
    first_name = cell_value(cells[2], shared_strings).to_s.strip
    next if first_name.empty? || last_name.empty?

    populated_attendance_cells = date_columns.filter_map do |column, day|
      cell = cells[column]
      next unless cell

      raw = cell_value(cell, shared_strings).to_s.strip
      [cell, day, raw] unless raw.empty?
    end
    next if populated_attendance_cells.empty?

    matches = students_by_name.fetch([first_name.downcase, last_name.downcase], [])
    if matches.length != 1
      problems << "#{sheet.attributes['name']}!A#{row.attributes['r']}: #{first_name} #{last_name} matched #{matches.length} students"
      next
    end
    student = matches.first

    populated_attendance_cells.each do |cell, day, raw|
      begin
        times = time_parts(raw)
        raise ArgumentError, "expected a complete check-in-checkout pair" unless times

        checkin = Time.zone.local(day.year, day.month, day.day, *times[0])
        checkout = Time.zone.local(day.year, day.month, day.day, *times[1])
        raise ArgumentError, "checkout precedes check-in" if checkout < checkin

        records << {
          student: student, day: day, checkin: checkin, checkout: checkout,
          source: "#{sheet.attributes['name']}!#{cell.attributes['r']}=#{raw}"
        }
      rescue ArgumentError => error
        problems << "#{sheet.attributes['name']}!#{cell.attributes['r']}: #{raw.inspect} (#{error.message})"
      end
    end
  end
end

duplicate_keys = records.group_by { |record| [record[:student].id, record[:day]] }.select { |_key, entries| entries.length > 1 }
duplicate_keys.each_value do |entries|
  entries.drop(1).each do |record|
    problems << "#{record[:source]}: duplicate student/day entry; first entry is #{entries.first[:source]}"
    records.delete(record)
  end
end

created = 0
skipped = 0
import_progress = { last_percent: -2 }
Attendance.transaction do
  records.each_with_index do |record, index|
    show_progress("Importing attendance", index + 1, records.length, import_progress)
    existing = Attendance.where(student_id: record[:student].id, day: record[:day]).to_a
    if existing.any?
      if existing.many?
        problems << "#{record[:source]}: multiple attendance records already exist for #{record[:student].full_name} on #{record[:day]}"
        next
      end

      existing = existing.first
      if existing.checkin == record[:checkin] && existing.checkout == record[:checkout]
        skipped += 1
        next
      end

      problems << "#{record[:source]}: attendance already exists for #{record[:student].full_name} on #{record[:day]} with different times"
      next
    end

    begin
      Attendance.transaction(requires_new: true) do
        Attendance.create!(
          student: record[:student], day: record[:day], checkin: record[:checkin],
          checkout: record[:checkout], checkin_by: staff.id
        )
      end
      created += 1
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
      problems << "#{record[:source]}: #{error.message.lines.first.to_s.strip}"
    end
  end
end

recalculated = 0
billing_problems = []
billing_records = records.uniq { |record| [record[:student].id, record[:day]] }
billing_progress = { last_percent: -2 }
billing_records.each_with_index do |record, index|
  show_progress("Recalculating billing", index + 1, billing_records.length, billing_progress)
  begin
    BillingRecord.recalculate!(student: record[:student], day: record[:day])
    recalculated += 1
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
    billing_problems << "#{record[:student].full_name} on #{record[:day]} (#{record[:source]}): #{error.message.lines.first.to_s.strip}"
  end
end

puts "Imported #{created} attendance records; skipped #{skipped} matching records."
puts "Recalculated billing for #{recalculated} student/day pair(s)."
if problems.empty?
  puts "All other workbook rows were imported."
else
  puts "Could not import #{problems.length} row(s):"
  problems.each { |problem| puts "- #{problem}" }
end
unless billing_problems.empty?
  puts "Could not recalculate billing for #{billing_problems.length} student/day pair(s):"
  billing_problems.each { |problem| puts "- #{problem}" }
end
