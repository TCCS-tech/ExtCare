require "test_helper"

class UserGoogleTest < ActiveSupport::TestCase
  def google_auth(email: "new@gmail.com", uid: "google-123", verified: true, hd: nil)
    { "provider" => "google_oauth2", "uid" => uid,
      "extra" => { "raw_info" => { "sub" => uid, "email" => email, "email_verified" => verified, "hd" => hd } } }
  end

  test "new Google accounts default to staff and can set a password" do
    assert_difference "User.count", 1 do
      user = User.from_google(google_auth)
      assert user.user?
      assert_equal "google-123", user.google_uid
      user.update!(password: "chosen-password")
      assert_equal user, User.authenticate_by(email: user.email, password: "chosen-password")
    end
  end

  test "matching Workspace account retains admin role and password" do
    admin = users(:admin)
    original_digest = admin.password_digest
    assert_no_difference "User.count" do
      assert_equal admin, User.from_google(google_auth(email: " ADMIN@EXAMPLE.COM ", hd: "example.com"))
    end
    assert admin.reload.admin?
    assert_equal original_digest, admin.password_digest
    assert admin.authenticate("password")
  end

  test "matching Gmail account links automatically" do
    user = User.create!(email: "existing@gmail.com", password: "password")
    assert_equal user, User.from_google(google_auth(email: user.email))
    assert_equal "google-123", user.reload.google_uid
  end

  test "third party address requires proof of the existing account" do
    auth = google_auth(email: users(:staff).email)
    assert_raises(User::GoogleLinkRequired) { User.from_google(auth) }
    assert_raises(User::GoogleLinkRequired) { User.from_google(auth, linking_user: users(:admin)) }
    assert_nil users(:staff).reload.google_uid
    assert_equal users(:staff), User.from_google(auth, linking_user: users(:staff))
  end

  test "linked Google identity remains stable when Google email changes" do
    user = User.from_google(google_auth)
    assert_no_difference "User.count" do
      assert_equal user, User.from_google(google_auth(email: users(:admin).email))
    end
    assert_equal "new@gmail.com", user.reload.email
    assert user.user?
  end

  test "different Google identity cannot replace a linked identity" do
    User.from_google(google_auth)
    assert_raises(User::InvalidGoogleAccount) do
      User.from_google(google_auth(uid: "another-google-id"))
    end
  end

  test "rejects missing or unverified identity data" do
    invalid = [ nil, google_auth(verified: false), google_auth(verified: "true"),
      google_auth(uid: ""), google_auth(email: ""), google_auth.merge("provider" => "other") ]
    mismatched = google_auth
    mismatched["extra"]["raw_info"]["sub"] = "different"
    invalid << mismatched
    assert_no_difference "User.count" do
      invalid.each { |auth| assert_raises(User::InvalidGoogleAccount) { User.from_google(auth) } }
    end
  end
end
