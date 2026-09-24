require "test_helper"

class AttendanceDatabaseRulesTest < ActiveSupport::TestCase
  setup do
    @student = Student.create!(first_name: "Mia", last_name: "Alvarez", grade: 1,
      blackbaud_id: "BB-MIA", student_id: "MIA")
    @checkin = Time.zone.local(2026, 9, 22, 15, 30)
  end

  test "direct inserts cannot check out before checkin" do
    assert_check_violation { insert_visit(checkout: @checkin - 1.second) }
  end

  test "direct updates cannot move checkout before checkin" do
    visit = insert_visit
    assert_check_violation { visit.update_columns(checkout: @checkin - 1.second) }
    assert_nil visit.reload.checkout
  end

  test "direct updates cannot move checkin after checkout" do
    visit = insert_visit(checkout: @checkin + 1.hour)
    assert_check_violation { visit.update_columns(checkin: @checkin + 2.hours) }
    assert_equal @checkin, visit.reload.checkin
  end

  test "checkout can equal checkin on insert and update" do
    visit = insert_visit(checkout: @checkin)
    assert_equal visit.checkin, visit.checkout
    visit.update_columns(checkin: @checkin + 1.minute, checkout: @checkin + 1.minute)
    assert_equal visit.reload.checkin, visit.checkout
  end

  test "direct inserts cannot span Pacific midnight even on the same UTC day" do
    assert_check_violation do
      insert_visit(checkin: Time.zone.local(2026, 9, 22, 23, 59),
        checkout: Time.zone.local(2026, 9, 23, 0, 1))
    end
  end

  test "direct updates cannot move either timestamp to a different Pacific day" do
    visit = insert_visit(checkout: @checkin + 1.hour)
    assert_check_violation { visit.update_columns(checkout: @checkin + 1.day) }
    assert_check_violation { visit.update_columns(checkin: @checkin - 1.day) }
    assert_equal @checkin, visit.reload.checkin
    assert_equal @checkin + 1.hour, visit.checkout
  end

  test "same day uses Pacific time regardless of the database session timezone" do
    visit = insert_visit
    Attendance.connection.execute("SET LOCAL timezone = 'UTC'")

    Attendance.connection.execute(<<~SQL)
      UPDATE attendance SET checkout = '2026-09-22 18:30:00-07' WHERE id = #{visit.id}
    SQL
    assert_equal Time.zone.local(2026, 9, 22, 18, 30), visit.reload.checkout

    assert_check_violation do
      Attendance.connection.execute(<<~SQL)
        UPDATE attendance
        SET checkin = '2026-09-22 23:59:00-07', checkout = '2026-09-23 00:01:00-07'
        WHERE id = #{visit.id}
      SQL
    end
  end

  test "an open visit blocks direct inserts of both open and completed visits on any day" do
    insert_visit

    [ nil, @checkin + 1.day + 1.hour ].each do |checkout|
      error = assert_raises(ActiveRecord::StatementInvalid) do
        Attendance.transaction(requires_new: true) do
          insert_visit(day: @checkin.to_date + 1, checkin: @checkin + 1.day, checkout: checkout)
        end
      end
      assert_kind_of PG::ExclusionViolation, error.cause
    end
    assert_equal 1, @student.attendances.count
  end

  test "an open visit does not block another student" do
    insert_visit
    other = Student.create!(first_name: "Noah", last_name: "Bennett", grade: 1,
      blackbaud_id: "BB-NOAH", student_id: "NOAH")
    assert insert_visit(student_id: other.id).persisted?
  end

  test "checking out an existing visit allows another insert" do
    visit = insert_visit
    visit.update_columns(checkout: @checkin + 1.hour)
    assert insert_visit(checkin: @checkin + 2.hours).persisted?
  end

  test "a completed visit can still be corrected while a newer visit is open" do
    completed = insert_visit(checkout: @checkin + 1.hour)
    insert_visit(checkin: @checkin + 2.hours)
    completed.update_columns(checkout: @checkin + 30.minutes)
    assert_equal @checkin + 30.minutes, completed.reload.checkout

    error = assert_raises(ActiveRecord::StatementInvalid) do
      Attendance.transaction(requires_new: true) { completed.update_columns(checkout: nil) }
    end
    assert_kind_of PG::ExclusionViolation, error.cause
  end

  private

  def insert_visit(**attributes)
    result = Attendance.insert_all!([ {
      student_id: @student.id, day: @checkin.to_date, checkin: @checkin,
      checkout: nil, checkin_by: users(:staff).id
    }.merge(attributes) ])
    Attendance.find(result.rows.first.first)
  end

  def assert_check_violation(&block)
    error = assert_raises(ActiveRecord::StatementInvalid) do
      Attendance.transaction(requires_new: true, &block)
    end
    assert_kind_of PG::CheckViolation, error.cause
  end
end
