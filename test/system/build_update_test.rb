require "application_system_test_case"

class BuildUpdateTest < ApplicationSystemTestCase
  test "a new build offers a reload without losing work until clicked" do
    visit new_session_path
    fill_in "Email", with: "unfinished@example.com"
    assert_no_selector "#build-update"

    page.execute_script(<<~JS)
      window.buildUpdateTest = true
      const originalFetch = window.fetch
      window.fetch = (input, options) => {
        if (input === "/build") {
          return Promise.resolve(new Response(JSON.stringify({ version: "next-build" }), {
            headers: { "Content-Type": "application/json" }
          }))
        }
        return originalFetch(input, options)
      }
      window.dispatchEvent(new Event("focus"))
    JS

    assert_selector "#build-update", text: "An update is available"
    assert_field "Email", with: "unfinished@example.com"
    click_link "Forgot password?"
    assert_current_path new_password_path
    assert_selector "#build-update", text: "An update is available"
    click_button "Reload"
    assert_no_selector "#build-update"
    assert_nil page.evaluate_script("window.buildUpdateTest")
  end
end
