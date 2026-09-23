require "test_helper"

class AttendanceTest < ActiveSupport::TestCase
  setup do
    @staff = users(:staff)
    @student = Student.create!(first_name: "Mia", last_name: "Alvarez", grade: 1)
    @day = Date.new(2026, 9, 22)
  end

  test "database session uses Pacific time" do
    assert_equal "America/Los_Angeles", Attendance.connection.select_value("SHOW timezone")
  end

  test "checkin is stored as Pacific wall time" do
    travel_to Time.zone.local(2026, 9, 22, 15, 30, 0) do
      attendance = Attendance.check_in(student: @student, by: @staff, day: @day)
      assert attendance.persisted?

      raw = Attendance.connection.select_value(
        "SELECT to_char(checkin, 'YYYY-MM-DD HH24:MI') FROM attendance WHERE id = #{attendance.id}"
      )
      assert_equal "2026-09-22 15:30", raw
      assert_equal 15, attendance.reload.checkin.hour
      assert_equal @staff.id, attendance.checkin_by
    end
  end

  test "a second checkin is refused while the first is open" do
    travel_to Time.zone.local(2026, 9, 22, 15, 30, 0) do
      assert Attendance.check_in(student: @student, by: @staff, day: @day).persisted?

      second = Attendance.check_in(student: @student, by: @staff, day: @day + 1)
      assert_not second.persisted?
      assert_match "Check out first", second.errors.full_messages.to_sentence
    end
  end

  test "checkout then another checkin on the same day" do
    travel_to Time.zone.local(2026, 9, 22, 15, 30, 0) do
      first = Attendance.check_in(student: @student, by: @staff, day: @day)
      first.check_out
      assert first.checkout > first.checkin
      assert_nil first.pickup_notes

      second = Attendance.check_in(student: @student, by: @staff, day: @day)
      assert second.persisted?
      assert_equal 2, @student.attendances.on(@day).count
    end
  end

  test "checkout cannot be before checkin" do
    attendance = Attendance.check_in(student: @student, by: @staff, day: @day)
    assert_raises(ActiveRecord::StatementInvalid) do
      attendance.update_columns(checkout: attendance.checkin - 1.minute)
    end
  end

  test "hidden students cannot be checked in" do
    @student.hide!
    attendance = Attendance.check_in(student: @student, by: @staff, day: @day)
    assert_not attendance.persisted?
  end
end
