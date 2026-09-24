class CreateBillingRecordsAndExtendedCareSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_records do |t|
      t.references :student, null: false, foreign_key: { on_delete: :restrict }
      t.date :day, null: false
      t.integer :am_cents, null: false, default: 0
      t.integer :pm_cents, null: false, default: 0
      t.integer :late_fee_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.text :notes, null: false, default: ""
      t.timestamps
    end
    add_index :billing_records, [ :student_id, :day ], unique: true

    create_table :extended_care_schedules do |t|
      t.date :day
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.timestamps
    end
    add_index :extended_care_schedules, :day, unique: true, where: "day IS NOT NULL"
    add_index :extended_care_schedules, :day, unique: true, where: "day IS NULL", name: "index_extended_care_schedules_default"
    add_check_constraint :extended_care_schedules, "end_time > start_time", name: "extended_care_schedule_end_after_start"

    reversible do |direction|
      direction.up do
        execute <<~SQL
          INSERT INTO extended_care_schedules (day, start_time, end_time, created_at, updated_at)
          VALUES (NULL, '15:00', '17:30', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end
    end
  end
end
