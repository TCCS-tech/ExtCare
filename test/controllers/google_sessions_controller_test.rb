require "test_helper"

class GoogleSessionsControllerTest < ActionDispatch::IntegrationTest
  def google_callback(email: "new@gmail.com", uid: "google-123", verified: true, hd: nil)
    auth = { "provider" => "google_oauth2", "uid" => uid,
      "extra" => { "raw_info" => { "sub" => uid, "email" => email, "email_verified" => verified, "hd" => hd } } }
    get "/api/auth/callback/google", env: { "omniauth.auth" => auth }
  end

  test "Google login creates a staff account and application session" do
    assert_difference({ "User.count" => 1, "Session.count" => 1 }) { google_callback }
    assert_redirected_to root_path
    assert cookies[:session_id]
    assert User.find_by!(google_uid: "google-123").user?
  end

  test "existing admin keeps privileges and requested destination" do
    get admin_users_path
    assert_redirected_to new_session_path
    assert_no_difference "User.count" do
      google_callback(email: users(:admin).email, hd: "example.com")
    end
    assert_redirected_to admin_users_url
    get admin_users_path
    assert_response :success
  end

  test "forged callback parameters cannot authenticate" do
    assert_no_difference [ "User.count", "Session.count" ] do
      get "/api/auth/callback/google", params: { uid: "forged", email: users(:admin).email, email_verified: true }
    end
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "unverified Google email cannot authenticate" do
    assert_no_difference([ "User.count", "Session.count" ]) { google_callback(verified: false) }
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "third party email links after successful matching password login" do
    google_callback(email: users(:staff).email)
    assert_redirected_to new_session_path
    assert_nil users(:staff).reload.google_uid
    post session_path, params: { email: users(:staff).email, password: "wrong" }
    assert_nil users(:staff).reload.google_uid
    post session_path, params: { email: users(:staff).email, password: "password" }
    assert_redirected_to root_path
    assert_equal "google-123", users(:staff).reload.google_uid
    delete session_path
    google_callback(email: users(:staff).email)
    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "signing in as another user does not link the pending Google account" do
    google_callback(email: users(:staff).email)
    post session_path, params: { email: users(:admin).email, password: "password" }
    assert_redirected_to root_path
    assert_nil users(:admin).reload.google_uid
    assert_nil users(:staff).reload.google_uid
  end

  test "pending link expires" do
    google_callback(email: users(:staff).email)
    travel 11.minutes do
      post session_path, params: { email: users(:staff).email, password: "password" }
    end
    assert_redirected_to root_path
    assert_nil users(:staff).reload.google_uid
  end

  test "Google failure clears the pending link" do
    google_callback(email: users(:staff).email)
    get "/auth/failure", params: { message: "access_denied" }
    assert_redirected_to new_session_path
    post session_path, params: { email: users(:staff).email, password: "password" }
    assert_nil users(:staff).reload.google_uid
  end
end
