require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
  end

  test "users page offers the current role for each account" do
    get admin_users_path
    assert_response :success
    assert_select "select#user_#{users(:staff).id}_role option[selected][value=user]", "Staff"
    assert_select "select#user_#{users(:admin).id}_role option[selected][value=admin]", "Admin"
  end

  test "admin can promote and demote users without changing their password or Google identity" do
    staff = users(:staff)
    staff.update!(google_uid: "staff-google-id")
    digest = staff.password_digest
    patch admin_user_path(staff), params: { user: { role: "admin" } }
    assert_redirected_to admin_users_path
    assert staff.reload.admin?
    assert_equal digest, staff.password_digest
    assert_equal "staff-google-id", staff.google_uid

    patch admin_user_path(staff), params: { user: { role: "user" } }
    assert_redirected_to admin_users_path
    assert staff.reload.user?
  end

  test "invalid role is rejected with an error on the users page" do
    patch admin_user_path(users(:staff)), params: { user: { role: "owner" } }
    assert_response :unprocessable_entity
    assert users(:staff).reload.user?
    assert_select ".alert-danger", /Role is not included in the list/
  end

  test "password updates still work without submitting a role" do
    patch admin_user_path(users(:staff)), params: { user: { password: "new-password", password_confirmation: "new-password" } }
    assert_redirected_to admin_users_path
    assert users(:staff).reload.authenticate("new-password")
    assert users(:staff).user?
  end

  test "staff cannot promote themselves" do
    sign_out
    sign_in_as users(:staff)
    patch admin_user_path(users(:staff)), params: { user: { role: "admin" } }
    assert_redirected_to root_path
    assert users(:staff).reload.user?
  end

  test "unauthenticated visitors cannot change roles" do
    sign_out
    patch admin_user_path(users(:staff)), params: { user: { role: "admin" } }
    assert_redirected_to new_session_path
    assert users(:staff).reload.user?
  end

  test "demoted admin loses admin access on the next request" do
    other_admin = User.create!(email: "other-admin@example.com", password: "password", role: :admin)
    other_session = open_session
    other_session.post session_path, params: { email: other_admin.email, password: "password" }
    patch admin_user_path(other_admin), params: { user: { role: "user" } }
    assert_redirected_to admin_users_path
    other_session.get admin_users_path
    other_session.assert_redirected_to root_path
  end
end
