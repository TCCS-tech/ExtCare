require "test_helper"

class AdminStudentsBillingTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
    @student = Student.create!(first_name: "Billing", last_name: "Student", grade: 1,
      blackbaud_id: "billing", student_id: "billing")
    @day = Date.new(2026, 9, 24)
    (@day - 1..@day + 1).each { |day| create_visits(@student, day) }
  end

  { staff: [ 0, 0 ], prepaid_am: [ 0, 1_000 ], prepaid_pm: [ 500, 0 ] }.each do |category, amounts|
    test "changing #{category} recalculates only this student's records starting on the chosen day" do
      other = Student.create!(first_name: "Other", last_name: "Student", grade: 1,
        blackbaud_id: "other", student_id: "other")
      create_visits(other, @day)
      before = @student.billing_records.find_by!(day: @day - 1).attributes
      other_before = other.billing_records.first.attributes

      patch admin_student_path(@student), params: { student: { category => "1", recalculate_billing_from: @day.iso8601 } }

      assert_redirected_to admin_students_path
      assert @student.reload.public_send(category)
      assert_equal before, @student.billing_records.find_by!(day: @day - 1).attributes
      assert_equal other_before, other.billing_records.first.attributes
      [ @day, @day + 1 ].each do |day|
        record = @student.billing_records.find_by!(day: day)
        assert_equal amounts, [ record.am_cents, record.pm_cents ]
        assert_equal amounts.sum, record.total_cents
      end

      patch admin_student_path(@student), params: { student: { category => "0", recalculate_billing_from: @day.iso8601 } }
      assert_equal 1_500, @student.billing_records.find_by!(day: @day).total_cents
    end
  end

  test "omitted and blank dates leave billing untouched" do
    before = @student.billing_records.order(:day).map(&:attributes)
    [ { staff: "1" }, { staff: "0", prepaid_pm: "1", recalculate_billing_from: "" } ].each do |attributes|
      patch admin_student_path(@student), params: { student: attributes }
      assert_redirected_to admin_students_path
      assert_equal before, @student.billing_records.order(:day).map(&:attributes)
    end
    assert @student.reload.prepaid_pm?
  end

  test "a date without a category change does not recalculate" do
    @student.update!(staff: true)
    before = @student.billing_records.order(:day).map(&:attributes)
    patch admin_student_path(@student), params: { student: { notes: "Updated", staff: "1", recalculate_billing_from: @day.iso8601 } }
    assert_redirected_to admin_students_path
    assert_equal before, @student.billing_records.order(:day).map(&:attributes)
  end

  test "invalid student edits preserve the date and leave billing untouched" do
    before = @student.billing_records.order(:day).map(&:attributes)
    patch admin_student_path(@student), params: { student: { staff: "1", grade: 7, recalculate_billing_from: @day.iso8601 } }
    assert_response :unprocessable_entity
    assert_select "input[type=date][value=?]", @day.iso8601
    assert_select "section[data-student-billing-target=section]:not([hidden])"
    assert_not @student.reload.staff?
    assert_equal before, @student.billing_records.order(:day).map(&:attributes)
  end

  test "invalid dates reject the category change" do
    patch admin_student_path(@student), params: { student: { staff: "1", recalculate_billing_from: "invalid" } }
    assert_response :unprocessable_entity
    assert_select ".alert-danger", text: /must be a valid date/
    assert_not @student.reload.staff?
  end

  private
    def create_visits(student, day)
      [ [ 7, 8 ], [ 15, 16 ] ].each do |checkin_hour, checkout_hour|
        Attendance.create!(student: student, recorded_by: users(:staff), day: day,
          checkin: Time.zone.local(day.year, day.month, day.day, checkin_hour),
          checkout: Time.zone.local(day.year, day.month, day.day, checkout_hour))
      end
    end
end
