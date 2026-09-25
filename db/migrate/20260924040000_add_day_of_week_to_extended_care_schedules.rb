class AddDayOfWeekToExtendedCareSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :extended_care_schedules, :day_of_week, :string
    add_check_constraint :extended_care_schedules, "day IS NULL OR day_of_week IS NULL",
      name: "extended_care_schedule_date_or_weekday"

    remove_index :extended_care_schedules, name: "index_extended_care_schedules_on_day"
    remove_index :extended_care_schedules, name: "index_extended_care_schedules_default"
    add_index :extended_care_schedules, :day, unique: true,
      where: "day IS NOT NULL", name: "index_extended_care_schedules_on_date"
    add_index :extended_care_schedules, :day_of_week, unique: true,
      where: "day_of_week IS NOT NULL", name: "index_extended_care_schedules_on_day_of_week"
    add_index :extended_care_schedules, :day, unique: true,
      where: "day IS NULL AND day_of_week IS NULL", name: "index_extended_care_schedules_default"
  end
end
