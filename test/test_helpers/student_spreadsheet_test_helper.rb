module StudentSpreadsheetTestHelper
  def student_backup_row(attributes = {})
    {
      "id" => "999999", "first_name" => "Import", "last_name" => "Student",
      "grade" => "0", "blackbaud_id" => "001234567890123456789", "student_id" => "001",
      "guardians" => '["Parent One","Parent Two"]', "additional_adults" => '["Grandparent"]',
      "staff" => "false", "prepaid_am" => "true", "prepaid_pm" => "false", "hidden" => "true",
      "notes" => "Original notes", "alert" => "An alert", "created_at" => "2020-01-01T00:00:00-08:00",
      "updated_at" => "2020-01-01T00:00:00-08:00"
    }.merge(attributes.stringify_keys)
  end

  def with_student_spreadsheet(rows, headers: Student.column_names)
    Tempfile.create([ "students", ".xlsx" ]) do |file|
      writer = SchoolYearRollover::Workbook.new(file.path, headers)
      rows.each { |row| writer.write(headers.map { |column| row[column] }) }
      writer.close
      upload = Rack::Test::UploadedFile.new(file.path,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", original_filename: "students.xlsx")
      yield upload
    end
  end
end
