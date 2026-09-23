require "test_helper"

class StudentTest < ActiveSupport::TestCase
  setup do
    @kindergarten = Student.create!(first_name: "Isla", last_name: "Thompson", grade: 0)
    @first = Student.create!(first_name: "Mia", last_name: "Alvarez", grade: 1)
  end

  test "kindergarten is stored as grade 0 and reads as K" do
    assert_predicate @kindergarten, :valid?
    assert_equal "K", @kindergarten.grade_label
    assert_equal "K", Student.grade_label(0)
    assert_equal "1", @first.grade_label
  end

  test "grades outside kindergarten through sixth are rejected" do
    assert_not Student.new(first_name: "Isla", last_name: "Torres", grade: -1).valid?
    assert_not Student.new(first_name: "Isla", last_name: "Underwood", grade: 7).valid?
  end

  test "grade levels are listed kindergarten first" do
    assert_equal [ "K", "1", "2", "3", "4", "5", "6" ], Student.grade_options.map(&:first)
  end

  test "the grade filter picks one level and ignores anything else" do
    assert_equal [ "Isla Thompson" ], Student.in_grade("0").ordered_by_name.map(&:full_name)
    assert_equal [ "Isla Thompson" ], Student.in_grade("K").ordered_by_name.map(&:full_name)
    assert_equal [ "Mia Alvarez" ], Student.in_grade("1").ordered_by_name.map(&:full_name)

    [ nil, "", "all", "0.5", "9", "K9" ].each do |filter|
      assert_equal 2, Student.in_grade(filter).count, "#{filter.inspect} should not filter by grade"
    end
  end

  test "flags read back as labels in display order" do
    assert_empty @first.flag_labels

    @first.update!(prepaid_pm: true, staff: true)
    assert_equal [ "Staff", "Prepaid PM" ], @first.reload.flag_labels

    @first.update!(prepaid_am: true)
    assert_equal [ "Staff", "Prepaid AM", "Prepaid PM" ], @first.reload.flag_labels
  end
end
