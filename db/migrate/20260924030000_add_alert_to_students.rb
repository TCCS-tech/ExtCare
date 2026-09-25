class AddAlertToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :alert, :text
  end
end
