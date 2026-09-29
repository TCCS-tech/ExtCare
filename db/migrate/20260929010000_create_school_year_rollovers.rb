class CreateSchoolYearRollovers < ActiveRecord::Migration[8.1]
  def change
    create_table :school_year_rollovers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :backup_key, null: false
      t.jsonb :fingerprints, null: false, default: {}
      t.datetime :downloaded_at
      t.datetime :completed_at
      t.text :error_message
      t.timestamps
    end
    add_index :school_year_rollovers, :backup_key, unique: true
    add_check_constraint :school_year_rollovers,
      "status IN ('pending', 'generating', 'ready', 'failed', 'completed')",
      name: "school_year_rollovers_status"
  end
end
