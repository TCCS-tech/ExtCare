require "test_helper"

class AdminBillingRecordsTest < ActionDispatch::IntegrationTest
  test "billing labels reflect the stored category instead of current student flags" do
    sign_in_as users(:admin)
    student = Student.create!(first_name: "Historical", last_name: "Billing", grade: 1,
      blackbaud_id: "historical", student_id: "historical", prepaid_pm: true)
    record = student.billing_records.create!(day: Date.current, billing_category: "staff, prepaid_am")

    get admin_billing_records_path
    assert_response :success
    assert_select "td .badge", text: "Staff"
    assert_select "td .badge", text: "Prepaid AM"
    assert_select "td .badge", text: "Prepaid PM", count: 0

    [ nil, "" ].each do |category|
      record.update!(billing_category: category)
      get admin_billing_records_path
      assert_response :success
      assert_select "td .badge", count: 0
    end
  end
end
