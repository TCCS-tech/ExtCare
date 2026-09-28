class AddBillingCategoryToBillingRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :billing_records, :billing_category, :text
  end
end
