class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.text :first_name, null: false
      t.text :last_name, null: false
      t.integer :grade, null: false
      t.text :blackbaud_id
      t.text :student_id
      t.text :guardians, array: true, null: false, default: []
      t.boolean :staff, null: false, default: false
      t.boolean :prepaid_am, null: false, default: false
      t.boolean :prepaid_pm, null: false, default: false
      t.boolean :hidden, null: false, default: false
      t.timestamps
    end

    add_index :students, :first_name
    add_index :students, :last_name
    add_index :students, :grade
    add_index :students, [:blackbaud_id, :student_id, :first_name, :last_name], unique: true
  end
end
