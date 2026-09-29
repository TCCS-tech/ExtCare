require "test_helper"

class AdminNewSchoolYearsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:admin)
  end

  teardown do
    FileUtils.rm_f(@rollover.backup_path) if @rollover
  end

  test "admin card and asynchronous backup with polling" do
    get admin_root_path
    assert_select "a[href=?]", new_admin_new_school_year_path, text: /New School Year/
    get new_admin_new_school_year_path
    assert_response :success
    assert_enqueued_with(job: SchoolYearBackupJob) { post admin_new_school_years_path }
    @rollover = SchoolYearRollover.last
    assert_redirected_to admin_new_school_year_path(@rollover)
    assert @rollover.pending?
    get admin_new_school_year_path(@rollover), as: :json
    assert_equal "waiting", response.parsed_body["step"]
    assert_equal "no-store", response.headers["Cache-Control"]
    get admin_new_school_year_path(@rollover)
    assert_select "[data-controller=school-year-wizard]"
    assert_select "input[name=confirmation]", count: 0
  end

  test "download is required and confirmation is exact even for direct requests" do
    @rollover = users(:admin).school_year_rollovers.create!(status: :ready)
    FileUtils.mkdir_p(SchoolYearRollover.backup_directory)
    File.write(@rollover.backup_path, "backup")
    patch admin_new_school_year_path(@rollover), params: { confirmation: "I UNDERSTAND" }
    assert_response :unprocessable_entity
    assert_nil @rollover.reload.completed_at
    get admin_new_school_year_path(@rollover)
    assert_select "button", text: "Download backup ZIP"
    post admin_new_school_year_download_path(@rollover)
    assert_response :success
    assert_equal "application/zip", response.media_type
    assert response.headers["Content-Disposition"].include?("attachment")
    assert @rollover.reload.downloaded_at
    get admin_new_school_year_path(@rollover), as: :json
    assert_equal "confirm", response.parsed_body["step"]
    [ "", "i understand", "I UNDERSTAND " ].each do |confirmation|
      patch admin_new_school_year_path(@rollover), params: { confirmation: confirmation }
      assert_response :unprocessable_entity
      assert_select "input[name=confirmation]"
    end
  end

  test "pending and missing backup files cannot be downloaded" do
    @rollover = users(:admin).school_year_rollovers.create!
    post admin_new_school_year_download_path(@rollover)
    assert_redirected_to admin_new_school_year_path(@rollover)
    assert_nil @rollover.reload.downloaded_at
    @rollover.update!(status: :ready)
    post admin_new_school_year_download_path(@rollover)
    assert_nil @rollover.reload.downloaded_at
  end

  test "staff cannot use any wizard endpoint" do
    @rollover = users(:admin).school_year_rollovers.create!
    sign_in_as users(:staff)
    get new_admin_new_school_year_path
    assert_redirected_to root_path
    post admin_new_school_years_path
    assert_redirected_to root_path
    get admin_new_school_year_path(@rollover), as: :json
    assert_redirected_to root_path
    post admin_new_school_year_download_path(@rollover)
    assert_redirected_to root_path
    patch admin_new_school_year_path(@rollover), params: { confirmation: "I UNDERSTAND" }
    assert_redirected_to root_path
  end

  test "another admin cannot access someone else's wizard" do
    other = User.create!(email: "other-admin@example.com", password: "password", role: "Admin")
    @rollover = other.school_year_rollovers.create!
    get admin_new_school_year_path(@rollover)
    assert_response :not_found
    post admin_new_school_year_download_path(@rollover)
    assert_response :not_found
    patch admin_new_school_year_path(@rollover), params: { confirmation: "I UNDERSTAND" }
    assert_response :not_found
  end

  test "interrupted job offers a fresh backup and duplicate starts reuse pending work" do
    @rollover = users(:admin).school_year_rollovers.create!
    assert_no_enqueued_jobs { post admin_new_school_years_path }
    assert_redirected_to admin_new_school_year_path(@rollover)
    @rollover.update!(updated_at: 3.hours.ago)
    get admin_new_school_year_path(@rollover), as: :json
    assert_equal "failed", response.parsed_body["step"]
    assert_enqueued_with(job: SchoolYearBackupJob) { post admin_new_school_years_path }
    assert_not_equal @rollover.id, SchoolYearRollover.last.id
  end
end
