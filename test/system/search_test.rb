require "application_system_test_case"

class SearchTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    @zara = Student.create!(first_name: "Zara", last_name: "Quill", grade: 4, blackbaud_id: "search-zara", student_id: "search-zara")
    visit new_session_path
    fill_in "Email", with: users(:admin).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Log out"
  end

  test "typing during a check-in search keeps the input and latest query" do
    visit checkins_path
    assert_typing_survives_search "Find a student", "checkins-results"
    click_button "4"
    assert_selector "button.btn-primary[data-roster-filter-grade-param='4']"
    assert_current_path(/grade=4(?:&|$)/)
    assert_selector "body[data-search-loaded='#{page.current_url}']"
    assert_equal "Zara", URI.decode_www_form(URI(find("a[aria-label='Previous day']")[:href]).query).to_h["q"]
    assert_equal "4", URI.decode_www_form(URI(find("a[aria-label='Previous day']")[:href]).query).to_h["grade"]
    within("#checkin_student_#{@zara.id}") { click_button "Check in" }
    assert_selector "#checkin-completed #checkin_student_#{@zara.id}"
    click_button "Clear search"
    assert_field "Find a student", with: ""
    assert_text "Frequent Check-ins"
  end

  test "typing during a check-out search keeps the input and latest query" do
    Attendance.check_in(student: @zara, by: users(:staff), day: Date.current)
    page.driver.browser.manage.window.resize_to(390, 844)
    visit checkouts_path
    assert_typing_survives_search "Find a student", "checkouts-results"
    within("#checkout-ready") { click_button "Check out" }
    assert_selector "#checkout-completed .student-name", text: "Zara Quill"
  end

  test "typing during a student search keeps the input and latest query" do
    visit admin_students_path
    assert_typing_survives_search "Student name", "student-search-results"
    click_button "Clear search"
    assert_text "Find a student to get started"
    assert_field "Student name", with: ""
    page.execute_script("delete document.body.dataset.searchLoaded")
    fill_in "Student name", with: "Zara"
    assert_current_path(/student_q=Zara(?:&|$)/)
    assert_selector "body[data-search-loaded='#{page.current_url}']"
    within("#student-results") { click_link "Edit" }
    assert_field "First name", with: "Zara"
  end

  private
    def assert_typing_survives_search(label, frame_id)
      input = find_field(label)
      # Hold the first response so more keystrokes arrive while it is in flight.
      page.execute_script(<<~JS, input)
        window.searchInput = arguments[0]
        document.addEventListener("turbo:load", () => {
          document.body.dataset.searchLoaded = window.location.href
        })
        const originalFetch = window.fetch
        window.fetch = async (...args) => {
          window.fetch = originalFetch
          const response = await originalFetch(...args)
          return new Promise(resolve => {
            window.releaseSearch = () => resolve(response)
            document.body.dataset.searchResponseReady = "true"
          })
        }
      JS
      input.send_keys("Za")
      assert_selector "body[data-search-response-ready='true']"
      input.send_keys("ra")
      page.execute_script("window.releaseSearch()")

      assert_selector "##{frame_id}", text: "Zara Quill"
      assert_current_path(/#{Regexp.escape(input[:name])}=Zara(?:&|$)/)
      assert_selector "body[data-search-loaded='#{page.current_url}']"
      assert_field label, with: "Zara", focused: true
      assert page.evaluate_script("window.searchInput === document.activeElement")
      assert_equal 4, page.evaluate_script("document.activeElement.selectionStart")
    end
end
