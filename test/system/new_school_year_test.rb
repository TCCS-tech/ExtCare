require "application_system_test_case"

class NewSchoolYearTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  self.use_transactional_tests = false

  DOWNLOAD_DIRECTORY = Rails.root.join("tmp", "school_year_download_test").to_s
  driven_by :selenium, using: :headless_chrome do |options|
    options.add_preference("download.default_directory", DOWNLOAD_DIRECTORY)
    options.add_preference("download.prompt_for_download", false)
  end

  teardown do
    FileUtils.rm_f(@rollover.backup_path) if @rollover
    FileUtils.rm_rf(DOWNLOAD_DIRECTORY)
    BillingRecord.delete_all
    Attendance.delete_all
    Student.delete_all
    SchoolYearRollover.delete_all
  end

  test "admin must wait download and type the confirmation before resetting" do
    visit new_session_path
    fill_in "Email", with: users(:admin).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Log out"
    visit admin_root_path
    click_link "New School Year"
    click_button "Create backup"
    assert_text "Creating your backup"
    assert_no_button "Download backup ZIP"
    @rollover = SchoolYearRollover.last
    perform_enqueued_jobs(only: SchoolYearBackupJob)
    assert_button "Download backup ZIP", wait: 10
    click_button "Download backup ZIP"
    assert_text "All student, attendance, and billing data will be permanently deleted.", wait: 10
    assert_button "Delete all student, attendance, and billing data", disabled: true
    fill_in "Type I UNDERSTAND exactly to continue", with: "i understand"
    assert_button "Delete all student, attendance, and billing data", disabled: true
    fill_in "Type I UNDERSTAND exactly to continue", with: "I UNDERSTAND"
    assert_button "Delete all student, attendance, and billing data", disabled: false
    click_button "Delete all student, attendance, and billing data"
    assert_text "6. Success!"
    assert @rollover.reload.completed?
    assert File.exist?(File.join(DOWNLOAD_DIRECTORY, @rollover.backup_filename))
  end
end
