class AddStudentIdToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :student_id, :text
  end
end
