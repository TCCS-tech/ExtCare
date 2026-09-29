require "test_helper"
require_relative "../test_helpers/student_spreadsheet_test_helper"

class AdminImportsTest < ActionDispatch::IntegrationTest
  include StudentSpreadsheetTestHelper

  test "admin card upload and repeated import" do
    sign_in_as users(:admin)
    get admin_root_path
    assert_select "a[href=?]", new_admin_import_path, text: /Import Data/
    get new_admin_import_path
    assert_response :success
    assert_select "input[type=file][name=file]"
    with_student_spreadsheet([ student_backup_row ]) do |file|
      assert_difference "Student.count", 1 do
        post admin_imports_path, params: { file: file }
      end
      assert_redirected_to new_admin_import_path
      assert_match "Added: 1", flash[:notice]
      assert_no_difference "Student.count" do
        post admin_imports_path, params: { file: file }
      end
      assert_match "unchanged: 1", flash[:notice]
    end
  end

  test "missing corrupt and non-xlsx uploads display useful errors" do
    sign_in_as users(:admin)
    post admin_imports_path
    assert_response :unprocessable_entity
    assert_select ".alert", text: /Choose a students.xlsx/
    Tempfile.create([ "invalid", ".xlsx" ]) do |file|
      file.write("not a spreadsheet")
      file.flush
      upload = Rack::Test::UploadedFile.new(file.path, "application/octet-stream", original_filename: "students.xlsx")
      post admin_imports_path, params: { file: upload }
      assert_response :unprocessable_entity
      assert_select ".alert", text: /No students were imported/
      upload = Rack::Test::UploadedFile.new(file.path, "text/plain", original_filename: "students.csv")
      post admin_imports_path, params: { file: upload }
      assert_response :unprocessable_entity
    end
  end

  test "staff and unauthenticated users cannot upload student data" do
    get new_admin_import_path
    assert_redirected_to new_session_path
    post admin_imports_path
    assert_redirected_to new_session_path
    sign_in_as users(:staff)
    get new_admin_import_path
    assert_redirected_to root_path
    with_student_spreadsheet([ student_backup_row ]) do |file|
      assert_no_difference "Student.count" do
        post admin_imports_path, params: { file: file }
      end
      assert_redirected_to root_path
    end
  end
end
