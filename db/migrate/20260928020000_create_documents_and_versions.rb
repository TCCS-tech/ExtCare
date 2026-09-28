class CreateDocumentsAndVersions < ActiveRecord::Migration[8.1]
  def up
    create_table :documents do |t|
      t.text :title, null: false
      t.text :body, null: false, default: ""
      t.timestamps
    end

    create_table :versions do |t|
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.text :table_name, null: false
      t.jsonb :data, null: false
    end

    execute <<~SQL
      CREATE FUNCTION extcare.version_document() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        INSERT INTO extcare.versions (created_at, table_name, data)
        VALUES (clock_timestamp(), TG_TABLE_NAME, to_jsonb(OLD));
        RETURN OLD;
      END;
      $$;

      CREATE TRIGGER documents_version_history
      AFTER UPDATE OR DELETE ON extcare.documents
      FOR EACH ROW EXECUTE FUNCTION extcare.version_document();
    SQL
  end

  def down
    drop_table :documents
    execute "DROP FUNCTION extcare.version_document()"
    drop_table :versions
  end
end
