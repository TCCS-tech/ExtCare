class AddAdditionalAdultsToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :additional_adults, :text, array: true, null: false, default: []
  end
end
