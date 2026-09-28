require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "body preserves rich text but excludes executable HTML and attachments" do
    document = Document.create!(title: " Safe ", body: '<p onclick="alert(1)"><strong>Welcome</strong><a href="javascript:alert(1)">link</a></p><img src="/file"><action-text-attachment sgid="secret"></action-text-attachment><table><tr><td>Cell</td></tr></table>')
    assert_equal "Safe", document.title
    assert_includes document.body, "<strong>Welcome</strong>"
    assert_includes document.body, "<td>Cell</td>"
    assert_no_match(/onclick|javascript:|<img|action-text-attachment|sgid/, document.body)
  end

  test "highlight colors survive persistence while unsafe styles are removed" do
    document = Document.create!(title: "Highlighted", body: '<p><mark style="color: var(--highlight-3); background-color: var(--highlight-bg-1); position: fixed; background-image: url(javascript:alert(1))" onclick="alert(1)">Remember</mark></p>')
    body = document.reload.body
    assert_includes body, "<mark"
    assert_includes body, "color:var(--highlight-3)"
    assert_includes body, "background-color:var(--highlight-bg-1)"
    assert_no_match(/onclick|javascript|position|background-image/, body)
  end

  test "SQL updates and deletes archive complete previous rows but inserts do not" do
    connection = Document.connection
    count = connection.select_value("SELECT count(*) FROM versions").to_i
    document = Document.create!(title: "Original", body: "<p>Original</p>")
    assert_equal count, connection.select_value("SELECT count(*) FROM versions").to_i
    original = connection.select_value("SELECT to_jsonb(documents) FROM documents WHERE id = #{document.id}")
    connection.execute("UPDATE documents SET title = 'Revised' WHERE id = #{document.id}")
    version = connection.select_one("SELECT * FROM versions ORDER BY id DESC LIMIT 1")
    assert_equal "documents", version["table_name"]
    assert_not_nil version["created_at"]
    assert_equal JSON.parse(original), JSON.parse(version["data"])

    revised = connection.select_value("SELECT to_jsonb(documents) FROM documents WHERE id = #{document.id}")
    connection.execute("DELETE FROM documents WHERE id = #{document.id}")
    assert_equal count + 2, connection.select_value("SELECT count(*) FROM versions").to_i
    assert_equal JSON.parse(revised), JSON.parse(connection.select_value("SELECT data FROM versions ORDER BY id DESC LIMIT 1"))
  end

  test "versions roll back with their document changes" do
    document = Document.create!(title: "Original")
    count = Document.connection.select_value("SELECT count(*) FROM versions")
    Document.transaction(requires_new: true) do
      document.update!(title: "Rolled back")
      document.delete
      raise ActiveRecord::Rollback
    end
    assert_equal "Original", document.reload.title
    assert_equal count, Document.connection.select_value("SELECT count(*) FROM versions")
  end
end
