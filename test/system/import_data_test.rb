require "application_system_test_case"
require_relative "../test_helpers/student_spreadsheet_test_helper"

class ImportDataTest < ApplicationSystemTestCase
  include StudentSpreadsheetTestHelper

  test "admin uploads a students backup and imports it again without duplicates" do
    visit new_session_path
    fill_in "Email", with: users(:admin).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Log out"
    visit admin_root_path
    click_link "Import Data"
    assert_text "Import students"
    with_student_spreadsheet([ student_backup_row ]) do |upload|
      attach_file "Students spreadsheet (.xlsx)", upload.tempfile.path
      click_button "Import students"
      assert_text "Student import complete. Added: 1, updated: 0, unchanged: 0."
      attach_file "Students spreadsheet (.xlsx)", upload.tempfile.path
      click_button "Import students"
      assert_text "Student import complete. Added: 0, updated: 0, unchanged: 1."
      assert_equal 1, Student.where(blackbaud_id: student_backup_row["blackbaud_id"]).count
    end
  end
end
