require "application_system_test_case"

class StudentBillingTest < ApplicationSystemTestCase
  test "recalculation is offered only while billing categories differ from saved values" do
    student = Student.create!(first_name: "Billing", last_name: "Student", grade: 1,
      blackbaud_id: "billing", student_id: "billing", prepaid_am: true)
    visit new_session_path
    fill_in "Email", with: users(:admin).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Log out"

    visit edit_admin_student_path(student)
    assert_no_text "Recalculate Billing"
    fill_in "Notes", with: "Updated"
    assert_no_text "Recalculate Billing"

    [ "Staff", "Prepaid PM" ].each do |label|
      check label
      assert_text "Recalculate Billing"
      assert_field "Recalculate from", disabled: false
      uncheck label
      assert_no_text "Recalculate Billing"
    end

    uncheck "Prepaid AM"
    find_field("Recalculate from").set(Date.new(2026, 9, 24))
    # Submit an invalid grade to exercise a server-side validation rerender.
    page.execute_script("document.querySelector('#student_grade').add(new Option('Invalid', '7', true, true))")
    click_button "Save changes"
    assert_text "Grade is not included"
    assert_field "Recalculate from", with: "2026-09-24"
    check "Prepaid AM"
    assert_no_text "Recalculate Billing"
  end
end
