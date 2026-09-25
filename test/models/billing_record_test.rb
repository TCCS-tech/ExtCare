require "test_helper"

class BillingRecordTest < ActiveSupport::TestCase
  setup do
    @student = Student.create!(first_name: "Mia", last_name: "Alvarez", grade: 1,
      blackbaud_id: "BB-MIA-BILLING", student_id: "MIA-BILLING")
    @day = Date.new(2026, 9, 25) # Friday
    @default_schedule = ExtendedCareSchedule.find_or_create_by!(day: nil, day_of_week: nil) do |schedule|
      schedule.start_time = "15:00"
      schedule.end_time = "17:30"
    end
  end

  test "billing uses a weekday override and lets a date override take priority" do
    @default_schedule.update!(start_time: "15:00", end_time: "17:30")
    friday_schedule = ExtendedCareSchedule.create!(day_of_week: "friday",
      start_time: "13:00", end_time: "15:00")
    date_schedule = ExtendedCareSchedule.create!(day: @day,
      start_time: "14:00", end_time: "16:00")
    Attendance.create!(student: @student, recorded_by: users(:staff), day: @day,
      checkin: Time.zone.local(2026, 9, 25, 14, 0),
      checkout: Time.zone.local(2026, 9, 25, 15, 5))

    assert_equal 0, BillingRecord.recalculate!(student: @student, day: @day).late_fee_cents

    date_schedule.destroy!
    assert_equal 2_500, BillingRecord.recalculate!(student: @student, day: @day).late_fee_cents

    friday_schedule.destroy!
    assert_equal 0, BillingRecord.recalculate!(student: @student, day: @day).late_fee_cents
  end
end
