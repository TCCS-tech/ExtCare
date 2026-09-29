require "test_helper"
require_relative "../test_helpers/student_spreadsheet_test_helper"

class StudentImportTest < ActiveSupport::TestCase
  include StudentSpreadsheetTestHelper

  test "backup imports all student fields with stable identifiers and repeated uploads are unchanged" do
    row = student_backup_row(first_name: "=SUM(1,2)", last_name: "A & <B>", alert: "literal _x0001_\ncontrol\u0001")
    with_student_spreadsheet([ row ]) do |upload|
      result = Student::Import.new(upload).save!
      assert_equal [ 1, 0, 0 ], [ result.created, result.updated, result.unchanged ]
      student = Student.find_by!(blackbaud_id: row["blackbaud_id"], student_id: row["student_id"])
      assert_equal "=SUM(1,2)", student.first_name
      assert_equal "A & <B>", student.last_name
      assert_equal row["alert"], student.alert
      assert_equal [ "Parent One", "Parent Two" ], student.guardians
      assert_equal [ "Grandparent" ], student.additional_adults
      assert student.hidden?
      assert student.prepaid_am?
      assert_not student.staff?
      assert_equal 0, student.grade
      assert_not_equal 999999, student.id
      assert_not_equal Time.zone.parse(row["created_at"]), student.created_at
      before = student.attributes
      result = Student::Import.new(upload).save!
      assert_equal [ 0, 0, 1 ], [ result.created, result.updated, result.unchanged ]
      assert_equal before, student.reload.attributes
    end
  end

  test "updates matching students and preserves attendance links and students absent from the file" do
    row = student_backup_row
    student = Student.create!(first_name: "Old", last_name: "Name", grade: 6,
      blackbaud_id: row["blackbaud_id"], student_id: row["student_id"])
    other = Student.create!(first_name: "Other", last_name: "Student", grade: 1, blackbaud_id: "other", student_id: "other")
    visit = Attendance.create!(student: student, recorded_by: users(:admin), day: Date.current, checkin: Time.current)
    bill = BillingRecord.create!(student: student, day: Date.current, total_cents: 500)
    with_student_spreadsheet([ row ]) do |upload|
      assert_no_difference "Student.count" do
        result = Student::Import.new(upload).save!
        assert_equal [ 0, 1, 0 ], [ result.created, result.updated, result.unchanged ]
      end
    end
    assert_equal "Import", student.reload.first_name
    assert_equal student.id, visit.reload.student_id
    assert_equal student.id, bill.reload.student_id
    assert_equal 500, bill.total_cents
    assert Student.exists?(other.id)
  end

  test "both family and student identifiers are used to match students" do
    row = student_backup_row
    with_student_spreadsheet([ row, row.merge("blackbaud_id" => "another-family") ]) do |upload|
      assert_difference "Student.count", 2 do
        assert_equal 2, Student::Import.new(upload).save!.created
      end
    end
  end

  test "a later invalid row rolls back earlier inserts and updates" do
    row = student_backup_row
    existing = Student.create!(first_name: "Original", last_name: "Student", grade: 1,
      blackbaud_id: row["blackbaud_id"], student_id: row["student_id"])
    invalid = row.merge("blackbaud_id" => "new", "grade" => "7")
    with_student_spreadsheet([ row, invalid ]) do |upload|
      assert_no_difference "Student.count" do
        error = assert_raises(Student::Import::InvalidFile) { Student::Import.new(upload).save! }
        assert_includes error.message, "row 3"
      end
    end
    assert_equal "Original", existing.reload.first_name
  end

  test "invalid arrays booleans names and grades are rejected without inserting rows" do
    [ { "guardians" => '"A name"' }, { "additional_adults" => "[1]" }, { "staff" => "maybe" },
      { "first_name" => "" }, { "grade" => "1.5" }, { "blackbaud_id" => " " } ].each do |attributes|
      with_student_spreadsheet([ student_backup_row(attributes) ]) do |upload|
        assert_no_difference "Student.count" do
          assert_raises(Student::Import::InvalidFile) { Student::Import.new(upload).save! }
        end
      end
    end
  end

  test "duplicate normalized identifiers are rejected and the import is rolled back" do
    row = student_backup_row
    with_student_spreadsheet([ row, row.merge("blackbaud_id" => " #{row['blackbaud_id']} ") ]) do |upload|
      assert_no_difference "Student.count" do
        error = assert_raises(Student::Import::InvalidFile) { Student::Import.new(upload).save! }
        assert_includes error.message, "appears more than once"
      end
    end
  end

  test "oversized uploads are rejected" do
    with_student_spreadsheet([ student_backup_row ]) do |upload|
      upload.define_singleton_method(:size) { Student::Import::MAX_UPLOAD_SIZE + 1 }
      error = assert_raises(Student::Import::InvalidFile) { Student::Import.new(upload).save! }
      assert_includes error.message, "20 MB"
    end
  end

  test "missing incorrect or duplicate headers are rejected" do
    [ Student.column_names - [ "guardians" ], Student.column_names + [ "unexpected" ],
      Student.column_names.map { |name| name == "grade" ? "student_id" : name } ].each do |headers|
      with_student_spreadsheet([ student_backup_row ], headers: headers) do |upload|
        assert_no_difference "Student.count" do
          assert_raises(Student::Import::InvalidFile) { Student::Import.new(upload).save! }
        end
      end
    end
  end

  test "multiple worksheets and shared strings from an Excel save are imported" do
    with_student_spreadsheet([ student_backup_row ]) do |upload|
      Zip::File.open(upload.tempfile.path) do |zip|
        sheet = zip.read("xl/worksheets/sheet1.xml")
        updated = sheet.sub('<c r="B2" t="inlineStr"><is><t xml:space="preserve">Import</t></is></c>', '<c r="B2" t="s"><v>0</v></c>')
        zip.get_output_stream("xl/worksheets/sheet1.xml") { |output| output.write(updated) }
        zip.get_output_stream("xl/sharedStrings.xml") do |output|
          output.write(%(<sst xmlns="#{Student::Import::Workbook::NAMESPACE}"><si><r><t>Shared </t></r><r><t>Name</t></r></si></sst>))
        end
        zip.get_output_stream("xl/worksheets/sheet2.xml") do |output|
          output.write(sheet.gsub("001234567890123456789", "another-family"))
        end
      end
      result = Student::Import.new(upload).save!
      assert_equal 2, result.created
      assert Student.exists?(first_name: "Shared Name")
    end
  end

  test "Excel Unicode escapes are decoded and null characters are rejected" do
    with_student_spreadsheet([ student_backup_row ]) do |upload|
      Zip::File.open(upload.tempfile.path) do |zip|
        sheet = zip.read("xl/worksheets/sheet1.xml").sub("An alert", "_xD83D__xDE00_")
        zip.get_output_stream("xl/worksheets/sheet1.xml") { |output| output.write(sheet) }
      end
      Student::Import.new(upload).save!
      assert_equal "😀", Student.find_by!(student_id: "001").alert
      Zip::File.open(upload.tempfile.path) do |zip|
        sheet = zip.read("xl/worksheets/sheet1.xml").sub("_xD83D__xDE00_", "_x0000_")
        zip.get_output_stream("xl/worksheets/sheet1.xml") { |output| output.write(sheet) }
      end
      assert_raises(Student::Import::InvalidFile) { Student::Import.new(upload).save! }
      assert_equal "😀", Student.find_by!(student_id: "001").alert
    end
  end

  test "formula cells malformed XML and document types cannot be imported" do
    [ :formula, :malformed, :doctype ].each do |kind|
      with_student_spreadsheet([ student_backup_row ]) do |upload|
        Zip::File.open(upload.tempfile.path) do |zip|
          sheet = zip.read("xl/worksheets/sheet1.xml")
          case kind
          when :formula then sheet = sheet.sub('<c r="B2"', '<c r="B2"><f>1+1</f></c><c r="B2"')
          when :malformed then sheet = sheet.sub("</worksheet>", "")
          when :doctype then sheet = '<!DOCTYPE worksheet [<!ENTITY unsafe SYSTEM "file:///etc/passwd">]>' + sheet
          end
          zip.get_output_stream("xl/worksheets/sheet1.xml") { |output| output.write(sheet) }
        end
        assert_no_difference "Student.count" do
          assert_raises(Student::Import::InvalidFile) { Student::Import.new(upload).save! }
        end
      end
    end
  end
end
