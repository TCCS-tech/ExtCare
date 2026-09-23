require "test_helper"

class AftercareFlowTest < ActionDispatch::IntegrationTest
  setup do
    @staff = users(:staff)
    @admin = users(:admin)
    @mia = Student.create!(first_name: "Mia", last_name: "Alvarez", grade: 1)
    @noah = Student.create!(first_name: "Noah", last_name: "Bennett", grade: 1)
    @liam = Student.create!(first_name: "Liam", last_name: "Diaz", grade: 2)
    @hidden = Student.create!(first_name: "Nora", last_name: "Vance", grade: 1, hidden: true)
  end

  test "visitors sign in before using the app" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "staff home links to check in and check out" do
    sign_in_as @staff
    get root_path
    assert_response :success
    assert_select "a", text: "Check in"
    assert_select "a", text: "Check out"
    assert_select "a", text: "Admin", count: 0
  end

  test "check in replaces the button with the time and keeps earlier visits" do
    sign_in_as @staff
    travel_to Time.zone.local(2026, 9, 22, 15, 30, 0) do
      post checkins_path, params: { student_id: @mia.id, day: "2026-09-22" }, as: :turbo_stream
      assert_response :success
      assert_includes response.body, "3:30 PM"
      assert_not_includes response.body, "Check in"

      patch_out = Attendance.last
      patch_out.check_out(by: @staff)

      get checkins_path(day: "2026-09-22")
      assert_select "#checkin_student_#{@mia.id}", text: /3:30 PM/
      assert_select "#checkin_student_#{@mia.id} button", text: "Check in"

      post checkins_path, params: { student_id: @mia.id, day: "2026-09-22" }, as: :turbo_stream
      assert_response :success
      assert_includes response.body, "3:30 PM"
      get checkins_path(day: "2026-09-22")
      assert_select "#checkin_student_#{@mia.id} button", count: 0
    end
  end

  test "students who were here yesterday sort first" do
    sign_in_as @staff
    Attendance.create!(
      student: @liam,
      day: Date.new(2026, 9, 21),
      checkin: Time.zone.local(2026, 9, 21, 15, 0),
      checkout: Time.zone.local(2026, 9, 21, 17, 0),
      checkin_by: @staff.id,
      checkout_by: @staff.email
    )

    get checkins_path(day: "2026-09-22")
    assert_operator response.body.index("Liam Diaz"), :<, response.body.index("Mia Alvarez")
    assert_select "#checkin_student_#{@liam.id}", text: /Here yesterday/
  end

  test "grade and name filters and hidden students" do
    sign_in_as @staff
    get checkins_path(grade: 2, q: "dia")
    assert_select ".student-name", text: "Liam Diaz"
    assert_select ".student-name", text: "Mia Alvarez", count: 0

    get checkins_path(q: "Nora")
    assert_select ".student-name", text: "Nora Vance", count: 0
  end

  test "checkout lists only open visits and turns the button into a time" do
    sign_in_as @staff
    travel_to Time.zone.local(2026, 9, 22, 16, 5, 0) do
      Attendance.check_in(student: @mia, by: @staff, day: Date.new(2026, 9, 22))
      get checkouts_path(day: "2026-09-22")
      assert_select ".student-name", text: "Mia Alvarez"
      assert_select ".student-name", text: "Noah Bennett", count: 0

      visit = Attendance.open.find_by!(student: @mia)
      post checkouts_path, params: { attendance_id: visit.id }, as: :turbo_stream
      assert_response :success
      assert_includes response.body, clock_text(visit.reload.checkout)
      assert_not_includes response.body, "Check out"

      get checkouts_path(day: "2026-09-22")
      assert_select ".student-name", text: "Mia Alvarez", count: 0
    end
  end

  test "an open visit from another day blocks a new checkin" do
    sign_in_as @staff
    Attendance.check_in(student: @mia, by: @staff, day: Date.new(2026, 9, 21))
    get checkins_path(day: "2026-09-22")
    assert_select "#checkin_student_#{@mia.id}", text: /Still checked in/
    assert_select "#checkin_student_#{@mia.id} button", count: 0

    get checkouts_path(day: "2026-09-22")
    assert_select "a", text: /September 21, 2026/
  end

  test "only admins can add and remove students" do
    sign_in_as @staff
    get admin_root_path
    assert_redirected_to root_path

    assert_no_difference -> { Student.count } do
      post admin_students_path, params: { student: { first_name: "New", last_name: "Kid", grade: 4 } }
    end
    assert_redirected_to root_path

    sign_in_as @admin
    get admin_root_path
    assert_response :success

    assert_difference -> { Student.count }, 1 do
      post admin_students_path, params: {
        student: { first_name: "New", last_name: "Kid", grade: 4, guardian_list: "Pat Kid, Sam Kid", blackbaud_id: "BB9" }
      }
    end
    student = Student.find_by!(last_name: "Kid")
    assert_equal [ "Pat Kid", "Sam Kid" ], student.guardians
    assert_redirected_to admin_root_path

    assert_no_difference -> { Student.count } do
      patch admin_student_path(student), params: { student: { hidden: true } }
    end
    assert student.reload.hidden?

    get checkins_path(q: "Kid")
    assert_select ".student-name", text: "New Kid", count: 0

    get admin_root_path(show_hidden: "1", student_q: "Kid")
    assert_select "td", text: /New Kid/
    patch admin_student_path(student), params: { student: { hidden: false } }
    assert_not student.reload.hidden?
  end

  test "admin can search a day's check-ins" do
    sign_in_as @admin
    travel_to Time.zone.local(2026, 9, 22, 15, 45, 0) do
      Attendance.check_in(student: @mia, by: @staff, day: Date.new(2026, 9, 22))
      get admin_root_path(day: "2026-09-22", attendance_q: "alv")
      assert_select "td", text: "Mia Alvarez"
      assert_select "td", text: @staff.email
      get admin_root_path(day: "2026-09-22", attendance_q: "liam")
      assert_select "td", text: "No check-ins on this day."
    end
  end

  private
    def clock_text(time)
      I18n.l(time, format: :check)
    end
end
