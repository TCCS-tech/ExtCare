require "test_helper"
require "zip"
require "tempfile"

class ImportSeptemberAttendanceTest < ActiveSupport::TestCase
  setup do
    @student = Student.create!(first_name: "Import", last_name: "Student", grade: 1,
      blackbaud_id: "SEPTEMBER-IMPORT", student_id: "SEPTEMBER-IMPORT")
    @day = Date.new(2026, 9, 22)
  end

  test "imports completed visits in bulk with billing and skips identical reimports" do
    statements = []
    subscriber = ->(_name, _start, _finish, _id, payload) { statements << payload[:sql] }
    output, progress = ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      import_rows([[@student, "300-400"], [@student, "300-430"]], days: [@day, @day + 1])
    end

    assert_equal 2, @student.attendances.count
    assert_equal [1_000, 1_500], @student.billing_records.order(:day).pluck(:total_cents)
    assert_equal 1, statements.count { |sql| sql.match?(/INSERT INTO "attendance"/) }
    assert_includes output, "Imported 2 attendance records; skipped 0 matching records."
    assert_includes progress, "Committing attendance..."
    assert_includes progress, "Recalculating billing"

    output, = import_rows([[@student, "300-400"], [@student, "300-430"]], days: [@day, @day + 1])
    assert_equal 2, @student.attendances.count
    assert_equal 2, @student.billing_records.count
    assert_includes output, "Imported 0 attendance records; skipped 2 matching records."
  end

  test "retains conflicting existing times and reports duplicate workbook entries" do
    attendance = Attendance.create!(student: @student, recorded_by: users(:staff), day: @day,
      checkin: stamp(15), checkout: stamp(16))

    output, = import_rows([[@student, "300-430"], [@student, "300-500"]])

    assert_equal stamp(16), attendance.reload.checkout
    assert_equal 1, @student.attendances.count
    assert_includes output, "with different times"
    assert_includes output, "duplicate student/day entry"
    assert_equal 1_000, @student.billing_records.find_by!(day: @day).total_cents
  end

  test "imports only dates in the inclusive range and ignores problems outside it" do
    days = [@day - 1, @day, @day + 1, @day + 2]
    unknown = Student.new(first_name: "Unknown", last_name: "Student")
    rows = [[unknown, "bad time"], [@student, "300-400"], [@student, "300-430"], [@student, "bad time"]]

    output, = import_rows(rows, days: days, arguments: [@day.to_s, (@day + 1).to_s])

    assert_equal [@day, @day + 1], @student.attendances.order(:day).pluck(:day)
    assert_equal [@day, @day + 1], @student.billing_records.order(:day).pluck(:day)
    assert_includes output, "Imported 2 attendance records"
    assert_not_includes output, "Could not import"
  end

  test "allows a single day range and a range with no workbook dates" do
    rows = [[@student, "300-400"], [@student, "300-430"]]
    output, = import_rows(rows, days: [@day, @day + 1], arguments: [@day.to_s, @day.to_s])
    assert_equal [@day], @student.attendances.pluck(:day)
    assert_includes output, "Imported 1 attendance records"

    output, = import_rows(rows, days: [@day, @day + 1], arguments: [(@day + 2).to_s, (@day + 3).to_s])
    assert_equal [@day], @student.attendances.pluck(:day)
    assert_includes output, "Imported 0 attendance records"
    assert_includes output, "Recalculated billing for 0 student/day pair(s)."
  end

  test "rejects incomplete invalid and reversed ranges before importing" do
    [[@day.to_s], ["2026-02-30", @day.to_s], ["20260922", @day.to_s],
      [(@day + 1).to_s, @day.to_s]].each do |arguments|
      error = assert_raises(SystemExit) { import_rows([[@student, "300-400"]], arguments: arguments) }
      assert_not error.success?
      assert_empty @student.attendances
      assert_empty @student.billing_records
    end
  end

  test "a database rejection in a batch still imports its other rows" do
    Attendance.create!(student: @student, recorded_by: users(:staff), day: @day - 1,
      checkin: stamp(15) - 1.day)
    other = Student.create!(first_name: "Other", last_name: "Student", grade: 1,
      blackbaud_id: "SEPTEMBER-OTHER", student_id: "SEPTEMBER-OTHER")

    output, = import_rows([[@student, "300-400"], [other, "300-400"]])

    assert_equal 1, @student.attendances.count
    assert_equal 1, other.attendances.count
    assert_equal 1_000, other.billing_records.find_by!(day: @day).total_cents
    assert_includes output, "Imported 1 attendance records; skipped 0 matching records."
    assert_includes output, "already has an open checkin"
  end

  private

  def stamp(hour)
    Time.zone.local(@day.year, @day.month, @day.day, hour)
  end

  def import_rows(rows, days: [@day], arguments: [])
    original_arguments = ARGV.dup
    ARGV.replace(arguments)
    Tempfile.create(["september", ".xlsx"]) do |file|
      cells = days.each_with_index.map do |day, index|
        %(<c r="#{(67 + index).chr}1"><v>#{(day - Date.new(1899, 12, 30)).to_i}</v></c>)
      end.join
      data = rows.each_with_index.map do |(student, value), index|
        row = index + 2
        column = (67 + index % days.length).chr
        %(<row r="#{row}">#{text_cell("A#{row}", student.last_name)}#{text_cell("B#{row}", student.first_name)}#{text_cell("#{column}#{row}", value)}</row>)
      end.join
      entries = {
        "xl/sharedStrings.xml" => '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"/>',
        "xl/workbook.xml" => '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="September" sheetId="1" r:id="rId1"/></sheets></workbook>',
        "xl/_rels/workbook.xml.rels" => '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>',
        "xl/worksheets/sheet1.xml" => %(<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1">#{cells}</row>#{data}</sheetData></worksheet>)
      }
      Zip::OutputStream.open(file.path) do |zip|
        entries.each do |name, xml|
          zip.put_next_entry(name)
          zip.write(xml)
        end
      end

      script = Rails.root.join("script/import_september_attendance.rb")
      # Substitute only the external workbook path; run the actual importer
      # without touching the private workbook or adding a production test hook.
      source = File.read(script).sub('Rails.root.join("_private/September.xlsx")', file.path.dump)
      namespace = Module.new
      namespace.extend(namespace)
      capture_io { namespace.module_eval(source, script.to_s) }
    end
  ensure
    ARGV.replace(original_arguments)
  end

  def text_cell(reference, text)
    %(<c r="#{reference}" t="inlineStr"><is><t>#{ERB::Util.html_escape(text)}</t></is></c>)
  end
end
