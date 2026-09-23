require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email" do
    user = User.new(email: " DOWNCASED@EXAMPLE.COM ")
    assert_equal "downcased@example.com", user.email
  end

  test "roles match the database labels" do
    assert users(:admin).admin?
    assert_not users(:staff).admin?
    assert_equal "Admin", users(:admin).role_before_type_cast
    assert_equal "User", users(:staff).role_before_type_cast
  end
end
