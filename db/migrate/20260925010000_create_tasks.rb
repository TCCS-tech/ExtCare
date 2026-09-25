class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.text :title, null: false
      t.text :description
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "todo"
      t.integer :priority, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :tasks, "status IN ('todo', 'done')", name: "tasks_status_valid"
    add_index :tasks, [ :status, :priority, :id ]
  end
end
