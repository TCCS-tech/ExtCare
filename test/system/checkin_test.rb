require "application_system_test_case"

class CheckinTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    @zara = Student.create!(first_name: "Zara", last_name: "Quill", grade: 4)
    @owen = Student.create!(first_name: "Owen", last_name: "Moss", grade: 1)
    @isla = Student.create!(first_name: "Isla", last_name: "Thompson", grade: 0)
  end

  test "staff checks students in and out from the lists" do
    sign_in users(:staff)
    assert_text "Welcome to"
    assert_no_link "Admin"

    within("nav") { click_link "Check in" }
    assert_text "Zara Quill"
    click_button "4"
    assert_text "Zara Quill"
    assert_no_text "Owen Moss"

    # Every filter click reloads the page. Wait for the grade 4 list to land so
    # the next click cannot be dropped mid-navigation.
    assert_selector "button.btn-primary[data-roster-filter-grade-param='4']"
    click_button "K"
    assert_text "Isla Thompson"
    assert_no_text "Zara Quill"
    assert_no_text "Owen Moss"
    click_button "All"
    assert_text "Owen Moss"

    fill_in "Find a student", with: "quil"
    assert_text "Zara Quill"
    assert_no_text "Owen Moss"

    # Headless Chrome drops the click while the search box still has focus.
    page.execute_script("document.activeElement && document.activeElement.blur()")
    within "#checkin_student_#{@zara.id}" do
      click_button "Check in"
      assert_no_button "Check in"
      assert_text(/\d{1,2}:\d{2} [AP]M/)
    end

    assert_selector "#checkin-completed #checkin_student_#{@zara.id}"
    assert_no_selector "#checkin-ready #checkin_student_#{@zara.id}"
    page.refresh
    assert_selector "#checkin-completed #checkin_student_#{@zara.id}"

    find("a[aria-label='Previous day']").click
    assert_text I18n.l(Date.current - 1, format: :long_day)

    within("nav") { click_link "Check out" }
    page.execute_script("document.activeElement && document.activeElement.blur()")
    within "#checkout_attendance_#{@zara.attendances.open.pick(:id)}" do
      click_button "Check out"
      assert_no_button "Check out"
      assert_text(/\d{1,2}:\d{2} [AP]M/)
    end

    assert_selector "#checkout-completed .student-name", text: "Zara Quill"
    assert_no_selector "#checkout-ready .student-name", text: "Zara Quill"
    page.refresh
    assert_selector "#checkout-completed .student-name", text: "Zara Quill"

    click_button "Log out"
    assert_text "Sign in"
  end

  test "admin adds and removes a student" do
    sign_in users(:admin)
    click_link "Admin"

    fill_in "First name", with: "Ada"
    fill_in "Last name", with: "Lovelace"
    select "4", from: "Grade"
    fill_in "Guardians", with: "Ann Lovelace, Charles Lovelace"
    click_button "Add student"

    assert_text "Ada Lovelace added."
    ada = Student.find_by!(last_name: "Lovelace")
    assert_equal [ "Ann Lovelace", "Charles Lovelace" ], ada.guardians

    fill_in "Search students", with: "Lovelace"
    within("tr", text: "Ada Lovelace") { click_link "Edit" }
    assert_field "First name", with: "Ada"
    fill_in "First name", with: "Augusta"
    select "5", from: "Grade"
    fill_in "Guardians", with: "Ann Lovelace"
    click_button "Save changes"
    assert_text "Augusta Lovelace updated."
    assert_equal "Augusta", ada.reload.first_name
    assert_equal 5, ada.grade
    assert_equal [ "Ann Lovelace" ], ada.guardians

    accept_confirm do
      within("tr", text: "Augusta Lovelace") { click_button "Remove" }
    end
    assert_text "Augusta Lovelace removed from the lists."
    assert ada.reload.hidden?

    within("nav") { click_link "Check in" }
    assert_no_text "Augusta Lovelace"
  end

  test "the menu works on a phone" do
    sign_in users(:staff)
    page.driver.browser.manage.window.resize_to(390, 844)
    visit checkins_path
    find("button[aria-label='Open menu']").click
    assert_selector "#primary-nav.show"
    click_link "Check out"
    assert_text "Check out"
    assert_button "All"
  end

  test "completed lists stay alphabetical when students finish out of order" do
    sign_in users(:staff)
    assert_button "Log out"
    visit checkins_path
    [ @zara, @owen ].each do |student|
      within("#checkin_student_#{student.id}") { click_button "Check in" }
      assert_selector "#checkin-completed #checkin_student_#{student.id}"
    end
    assert_equal [ "Owen Moss", "Zara Quill" ], all("#checkin-completed .student-name").map(&:text)

    visit checkouts_path
    [ @zara, @owen ].each do |student|
      visit_id = student.attendances.open.pick(:id)
      within("#checkout_attendance_#{visit_id}") { click_button "Check out" }
      assert_selector "#checkout-completed #checkout_attendance_#{visit_id}"
    end
    assert_equal [ "Owen Moss", "Zara Quill" ], all("#checkout-completed .student-name").map(&:text)
  end

  test "admin checkin search preserves scroll and input focus" do
    10.times do |index|
      time = Time.current - (30 - index * 2).minutes
      Attendance.create!(student: @owen, day: Date.current, checkin: time,
        checkout: time + 1.minute, checkin_by: users(:staff).id, pickup_notes: "Jordan Quill")
    end
    Attendance.check_in(student: @zara, by: users(:staff), day: Date.current)
    sign_in users(:admin)
    assert_button "Log out"
    visit admin_root_path
    page.driver.browser.manage.window.resize_to(1000, 650)
    input = find("#attendance_q")
    page.execute_script("arguments[0].scrollIntoView({block: 'center'})", input)
    input.click
    scroll = page.evaluate_script("window.scrollY")
    assert_operator scroll, :>, 0

    fill_in "Search check-ins", with: "Owen"
    within "#admin-checkin-results" do
      assert_no_text "Zara Quill"
      assert_text "Owen Moss"
    end
    assert_in_delta scroll, page.evaluate_script("window.scrollY"), 2
    assert_equal "attendance_q", page.evaluate_script("document.activeElement.id")
    assert_field "Search check-ins", with: "Owen"
  end

  private
    def sign_in(user)
      visit new_session_path
      fill_in "Email", with: user.email
      fill_in "Password", with: "password"
      click_button "Sign in"
    end
end
