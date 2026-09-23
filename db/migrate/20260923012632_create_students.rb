class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.text :first_name, null: false
      t.text :last_name, null: false
      t.integer :grade, null: false
      t.text :blackbaud_id
      t.text :guardians, array: true, null: false, default: []
      t.boolean :hidden, null: false, default: false
      t.timestamps
    end

    add_index :students, [ :first_name, :last_name ], unique: true, name: "students_name_key"
    add_index :students, :blackbaud_id, unique: true
  end
end
