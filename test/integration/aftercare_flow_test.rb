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
    assert_select "p.home-footer > a[href=?][target=_blank][rel=noopener]", "https://tccs.org", text: "Tri-City Christian School"
  end

  test "home greeting follows the time of day" do
    sign_in_as @staff

    travel_to Time.zone.local(2026, 9, 22, 9, 15, 0) do
      get root_path
      assert_select "h2#actions-heading", text: "Here for the morning."
    end

    travel_to Time.zone.local(2026, 9, 22, 12, 0, 0) do
      get root_path
      assert_select "h2#actions-heading", text: "Here for the afternoon."
    end
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
      assert_select "#checkin-ready #checkin_student_#{@mia.id} button", text: "Check in"

      post checkins_path, params: { student_id: @mia.id, day: "2026-09-22" }, as: :turbo_stream
      assert_response :success
      assert_includes response.body, "3:30 PM"
      get checkins_path(day: "2026-09-22")
      assert_select "#checkin_student_#{@mia.id} button", count: 0
      assert_select "#checkin-completed #checkin_student_#{@mia.id}"
      assert_select "#checkin-ready #checkin_student_#{@noah.id}"
    end
  end

  test "checkin students sort by first name even when another student was here yesterday" do
    sign_in_as @staff
    Attendance.create!(
      student: @mia,
      day: Date.new(2026, 9, 21),
      checkin: Time.zone.local(2026, 9, 21, 15, 0),
      checkout: Time.zone.local(2026, 9, 21, 17, 0),
      checkin_by: @staff.id,
      checkout_by: @staff.email
    )

    get checkins_path(day: "2026-09-22")
    assert_operator response.body.index("Liam Diaz"), :<, response.body.index("Mia Alvarez")
    assert_select "#checkin_student_#{@mia.id}", text: /Here yesterday/
  end

  test "the day arrows and the day param stop at today" do
    sign_in_as @staff
    yesterday = Date.current - 1

    get checkins_path(day: yesterday)
    assert_select "a[aria-label='Next day'][href=?]", checkins_path(day: yesterday + 1)

    get checkins_path(day: Date.current)
    assert_select "a[aria-label='Next day']", count: 0
    assert_select "button[disabled][aria-label='Next day']", count: 1

    get checkins_path(day: Date.current + 3)
    assert_select "input[name='day'][value=?]", Date.current.iso8601
    assert_select "a[aria-label='Next day']", count: 0

    get checkouts_path(day: Date.current + 3)
    assert_select "input[name='day'][value=?]", Date.current.iso8601
    assert_select "a[aria-label='Next day']", count: 0

    sign_in_as @admin

    get admin_root_path(day: Date.current + 3)
    assert_select "input#attendance_day[value=?]", Date.current.iso8601
    assert_select "input#attendance_day[max=?]", Date.current.iso8601
  end

  test "a check-in aimed at a future day is recorded for today" do
    sign_in_as @staff

    post checkins_path, params: { student_id: @mia.id, day: (Date.current + 3).iso8601 }, as: :turbo_stream

    assert_equal Date.current, Attendance.last.day
    assert_operator Attendance.last.checkin, :<=, Time.current
  end

  test "grade and name filters and hidden students" do
    sign_in_as @staff
    get checkins_path(grade: 2, q: "dia")
    assert_select ".student-name", text: "Liam Diaz"
    assert_select ".student-name", text: "Mia Alvarez", count: 0

    get checkins_path(q: "Nora")
    assert_select ".student-name", text: "Nora Vance", count: 0
  end

  test "checkout separates open and completed visits and keeps completion after refresh" do
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
      assert_select "#checkout-ready .student-name", text: "Mia Alvarez", count: 0
      assert_select "#checkout-completed .student-name", text: "Mia Alvarez"
      assert_select "#checkout-completed button", count: 0
    end
  end

  test "an open visit from another day blocks a new checkin" do
    sign_in_as @staff
    Attendance.check_in(student: @mia, by: @staff, day: Date.new(2026, 9, 21))
    get checkins_path(day: "2026-09-22")
    assert_select "#checkin_student_#{@mia.id}", text: /Still checked in/
    assert_select "#checkin_student_#{@mia.id} button", count: 0
      assert_select "#checkin-completed #checkin_student_#{@mia.id}"
      assert_select "#checkin-ready #checkin_student_#{@noah.id}"

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

  test "admin edits student details while preserving attendance and filters" do
    sign_in_as @admin
    visit = Attendance.check_in(student: @mia, by: @staff, day: Date.current)
    @mia.hide!
    filters = { student_q: "Alvarez", show_hidden: "1", day: Date.current.to_s }
    get edit_admin_student_path(@mia), params: filters
    assert_response :success
    assert_select "input[name='student[first_name]'][value='Mia']"
    assert_select "a[href=?]", admin_root_path(filters), text: "Cancel"

    patch admin_student_path(@mia), params: filters.merge(student: {
      first_name: "Maria", last_name: "Alvarez", grade: 3,
      blackbaud_id: "BB-EDIT", guardian_list: "Ana Alvarez, Luis Alvarez"
    })
    assert_redirected_to admin_root_path(filters)
    @mia.reload
    assert_equal "Maria Alvarez", @mia.full_name
    assert_equal 3, @mia.grade
    assert_equal "BB-EDIT", @mia.blackbaud_id
    assert_equal [ "Ana Alvarez", "Luis Alvarez" ], @mia.guardians
    assert @mia.hidden?
    assert_equal @mia.id, visit.reload.student_id
  end

  test "invalid edits show errors and preserve submitted values without saving" do
    sign_in_as @admin
    patch admin_student_path(@mia), params: { student: { first_name: "Noah", last_name: "Bennett", grade: 4 } }
    assert_response :unprocessable_entity
    assert_select ".alert-danger", text: /already used/
    assert_select "input[name='student[first_name]'][value='Noah']"
    assert_equal "Mia Alvarez", @mia.reload.full_name
    assert_equal 1, @mia.grade
  end

  test "staff cannot open or submit student edits" do
    sign_in_as @staff
    get edit_admin_student_path(@mia)
    assert_redirected_to root_path
    patch admin_student_path(@mia), params: { student: { first_name: "Changed", grade: 6 } }
    assert_redirected_to root_path
    assert_equal "Mia", @mia.reload.first_name
    assert_equal 1, @mia.grade
  end

  test "checkout and admin student lists sort by first name" do
    sign_in_as @admin
    [ @mia, @noah, @liam ].each do |student|
      Attendance.check_in(student: student, by: @staff, day: Date.current)
    end
    get checkouts_path
    assert_select "#checkout-ready .student-name" do |names|
      assert_equal [ "Liam Diaz", "Mia Alvarez", "Noah Bennett" ], names.map(&:text)
    end
    Attendance.open.each { |visit| visit.check_out(by: @staff) }
    get checkouts_path
    assert_select "#checkout-completed .student-name" do |names|
      assert_equal [ "Liam Diaz", "Mia Alvarez", "Noah Bennett" ], names.map(&:text)
    end
    get admin_root_path(student_q: "a")
    assert_select "#student-results tbody tr" do |rows|
      assert_match /Liam Diaz/, rows.first.text
      assert_match /Mia Alvarez/, rows[1].text
    end
  end

  test "admin student results require a nonblank search even when showing removed students" do
    sign_in_as @admin
    [ nil, "", "   " ].each do |query|
      get admin_root_path(student_q: query, show_hidden: "1")
      assert_response :success
      assert_select "#student-results table", count: 0
      assert_select "#student-results", text: /Type a student’s name/
    end

    get admin_root_path(student_q: "mia")
    assert_select "#student-results td", text: "Mia Alvarez"
    assert_select "#student-results td", text: "Noah Bennett", count: 0

    get admin_root_path(student_q: "no-such-student")
    assert_select "#student-results", text: /No students match/
  end

  test "attendance switch preserves filters in both directions" do
    sign_in_as @staff
    filters = { day: "2026-09-21", grade: "2", q: "Liam" }
    get checkins_path(filters)
    assert_select ".attendance-switch a[aria-current='page']", text: "Check in"
    assert_select ".attendance-switch a[href=?]", checkouts_path(filters), text: "Check out"

    get checkouts_path(filters)
    assert_select ".attendance-switch a[aria-current='page']", text: "Check out"
    assert_select ".attendance-switch a[href=?]", checkins_path(filters), text: "Check in"
  end

  private
    def clock_text(time)
      I18n.l(time, format: :check)
    end
end
