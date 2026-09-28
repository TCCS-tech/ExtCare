require "test_helper"

class AdminDocumentsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
    @document = Document.create!(title: "Family handbook", body: "<p>Welcome</p>")
  end

  test "admin can find create and edit documents" do
    get admin_root_path
    assert_select "a[href=?]", admin_documents_path
    get admin_documents_path
    assert_select "a[href=?]", admin_document_path(@document), text: /Family handbook/
    get new_admin_document_path
    assert_select "lexxy-editor[name='document[body]'][attachments=false]"

    assert_difference "Document.count" do
      post admin_documents_path, params: { document: { title: "Pickup", body: "<p><strong>Bring ID</strong></p>" } }
    end
    document = Document.order(:id).last
    assert_redirected_to admin_document_path(document)
    get edit_admin_document_path(document)
    assert_select "lexxy-editor[value=?]", document.body
    patch admin_document_path(document), params: { document: { title: "Pickup policy", body: "<p>Updated</p>" } }
    assert_redirected_to admin_document_path(document)
    assert_equal "<p>Updated</p>", document.reload.body
  end

  test "show renders sanitized rich text without an editor" do
    @document.update_columns(body: '<p><strong>Welcome</strong></p><script>alert(1)</script><img src=x onerror="alert(1)">')
    get admin_document_path(@document)
    assert_response :success
    assert_select ".lexxy-content strong", text: "Welcome"
    assert_select ".lexxy-content script, .lexxy-content img, lexxy-editor", count: 0
    assert_select "a[href=?]", edit_admin_document_path(@document), text: "Edit"
    assert_select "form[action=?][data-turbo-confirm]", admin_document_path(@document)
  end

  test "deleting a document archives it and redirects to the index" do
    assert_difference "Document.count", -1 do
      delete admin_document_path(@document)
    end
    assert_response :see_other
    assert_redirected_to admin_documents_path
    version = JSON.parse(Document.connection.select_value("SELECT data FROM versions WHERE table_name = 'documents' ORDER BY id DESC LIMIT 1"))
    assert_equal @document.id, version["id"]
    assert_equal @document.body, version["body"]
  end

  test "invalid creates and edits preserve entered content" do
    assert_no_difference "Document.count" do
      post admin_documents_path, params: { document: { title: " ", body: "<p>Draft</p>" } }
    end
    assert_response :unprocessable_entity
    assert_select "lexxy-editor[value=?]", "<p>Draft</p>"
    patch admin_document_path(@document), params: { document: { title: "", body: "<p>Revision</p>" } }
    assert_response :unprocessable_entity
    assert_select "lexxy-editor[value=?]", "<p>Revision</p>"
    assert_equal "Family handbook", @document.reload.title
  end

  test "staff and signed out users cannot access or change documents" do
    [ users(:staff), nil ].each do |user|
      sign_out
      sign_in_as(user) if user
      destination = user ? root_path : new_session_path
      get admin_documents_path
      assert_redirected_to destination
      get new_admin_document_path
      assert_redirected_to destination
      get admin_document_path(@document)
      assert_redirected_to destination
      get edit_admin_document_path(@document)
      assert_redirected_to destination
      assert_no_difference "Document.count" do
        post admin_documents_path, params: { document: { title: "Unauthorized" } }
      end
      assert_redirected_to destination
      patch admin_document_path(@document), params: { document: { title: "Unauthorized" } }
      assert_redirected_to destination
      assert_no_difference "Document.count" do
        delete admin_document_path(@document)
      end
      assert_redirected_to destination
      assert_equal "Family handbook", @document.reload.title
    end
  end
end
