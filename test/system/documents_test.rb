require "application_system_test_case"

class DocumentsTest < ApplicationSystemTestCase
  test "admin reads edits and confirms deletion of a document" do
    visit new_session_path
    fill_in "Email", with: users(:admin).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Admin"
    click_link "Documents"
    click_link "New document"
    fill_in "Title", with: "Family handbook"
    editor = find("lexxy-editor [contenteditable=true]")
    editor.click
    find("lexxy-editor button[name=bold]").click
    find("lexxy-editor button[name=highlight]").click
    find('lexxy-editor button[name="color-2"]').click
    find("lexxy-editor button[name=highlight]").click
    find('lexxy-editor button[name="background-color-0"]').click
    editor.send_keys("Welcome families")
    assert_no_selector "lexxy-editor input[type=file]", visible: :all
    click_button "Create document"
    assert_text "Document created."
    assert_selector ".lexxy-content strong", text: "Welcome families"
    assert_selector '.lexxy-content mark[style*="--highlight-3"][style*="--highlight-bg-1"]', text: "Welcome families"
    assert_no_selector "lexxy-editor"
    assert_equal [ "rgb(207, 0, 0)", "rgba(229, 223, 6, 0.3)" ], find(".lexxy-content mark").evaluate_script("[getComputedStyle(this).color, getComputedStyle(this).backgroundColor]")
    visit current_path
    assert_equal [ "rgb(207, 0, 0)", "rgba(229, 223, 6, 0.3)" ], find(".lexxy-content mark").evaluate_script("[getComputedStyle(this).color, getComputedStyle(this).backgroundColor]")
    click_link "Back to Documents"
    click_link "Family handbook"
    click_link "Edit"
    assert_selector "lexxy-editor [contenteditable=true] strong", text: "Welcome families"
    assert_selector 'lexxy-editor [contenteditable=true] mark[style*="--highlight-3"][style*="--highlight-bg-1"]', text: "Welcome families"
    find("lexxy-editor [contenteditable=true]").send_keys(:end, " Updated")
    click_button "Save changes"
    assert_text "Document updated."
    assert_selector ".lexxy-content", text: "Updated"
    dismiss_confirm('Delete "Family handbook"?') { click_button "Delete" }
    assert_selector ".lexxy-content", text: "Updated"
    assert_button "Delete"
    accept_confirm('Delete "Family handbook"?') { click_button "Delete" }
    assert_text "Document deleted."
    assert_no_link "Family handbook"
    assert_text "No documents yet."
  end
end
