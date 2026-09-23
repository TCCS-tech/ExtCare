class AddFlagsToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :staff, :boolean, null: false, default: false
    add_column :students, :prepaid_am, :boolean, null: false, default: false
    add_column :students, :prepaid_pm, :boolean, null: false, default: false
  end
end
