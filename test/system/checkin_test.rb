require "application_system_test_case"

class CheckinTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    @zara = Student.create!(first_name: "Zara", last_name: "Quill", grade: 4)
    @owen = Student.create!(first_name: "Owen", last_name: "Moss", grade: 1)
  end

  test "staff checks students in and out from the lists" do
    sign_in users(:staff)
    assert_text "Check students in and out."
    assert_no_link "Admin"

    click_link "Check in"
    assert_text "Zara Quill"
    click_button "4"
    assert_text "Zara Quill"
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

    find("a[aria-label='Previous day']").click
    assert_text I18n.l(Date.current - 1, format: :long_day)

    within("nav") { click_link "Check out" }
    page.execute_script("document.activeElement && document.activeElement.blur()")
    within "#checkout_attendance_#{@zara.attendances.open.pick(:id)}" do
      click_button "Check out"
      assert_no_button "Check out"
      assert_text(/\d{1,2}:\d{2} [AP]M/)
    end

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

    accept_confirm do
      within("tr", text: "Ada Lovelace") { click_button "Remove" }
    end
    assert_text "Ada Lovelace removed from the lists."
    assert ada.reload.hidden?

    click_link "Check in"
    assert_no_text "Ada Lovelace"
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

  private
    def sign_in(user)
      visit new_session_path
      fill_in "Email", with: user.email
      fill_in "Password", with: "password"
      click_button "Sign in"
    end
end
