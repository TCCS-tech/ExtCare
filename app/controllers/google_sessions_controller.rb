class GoogleSessionsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_session_path, alert: "Try again later." }

  def create
    session.delete(:pending_google_link)
    auth = request.env["omniauth.auth"]
    user = User.from_google(auth)
    start_new_session_for user
    redirect_to after_authentication_url
  rescue User::GoogleLinkRequired
    # Store only verified identity data, never Google's access or refresh tokens.
    session[:pending_google_link] = {
      "provider" => auth["provider"], "uid" => auth["uid"],
      "extra" => { "raw_info" => auth.dig("extra", "raw_info").slice("sub", "email", "email_verified") },
      "expires_at" => 10.minutes.from_now.to_i
    }
    redirect_to new_session_path, alert: "Sign in with your existing email and password once to connect Google. You can then use either sign-in method."
  rescue User::InvalidGoogleAccount, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to new_session_path, alert: "Google sign-in could not be completed. Please try again or sign in with your password."
  end

  def failure
    session.delete(:pending_google_link)
    redirect_to new_session_path, alert: "Google sign-in was cancelled or failed. Please try again."
  end
end
