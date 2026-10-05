require "test_helper"

class GoogleOauthSecurityTest < ActiveSupport::TestCase
  setup do
    @strategy = OmniAuth::Strategies::GoogleOauth2.new(
      ->(_env) { [ 404, {}, [ "Not found" ] ] }, "test-client", "test-secret",
      callback_path: "/api/auth/callback/google")
    @original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_forgery_protection
  end

  test "Google sign-in cannot start with GET" do
    response = @strategy.call(Rack::MockRequest.env_for("/auth/google_oauth2", "rack.session" => {}))
    assert_equal 404, response[0]
  end

  test "Google sign-in POST requires an authenticity token" do
    response = @strategy.call(Rack::MockRequest.env_for("/auth/google_oauth2", method: "POST", "rack.session" => {}))
    assert_equal 302, response[0]
    assert_match "/auth/failure", response[1]["location"]
    assert_match "InvalidAuthenticityToken", response[1]["location"]
  end

  test "callback rejects missing or mismatched OAuth state before exchanging a code" do
    [ {}, { "omniauth.state" => "expected" } ].each do |oauth_session|
      expected_state = oauth_session["omniauth.state"]
      response = @strategy.call(Rack::MockRequest.env_for(
        "/api/auth/callback/google?code=forged&state=wrong", "rack.session" => oauth_session))
      assert_equal 302, response[0]
      assert_match "/auth/failure", response[1]["location"]
      assert_match "csrf_detected", response[1]["location"] if expected_state
    end
  end
end
