class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
    redirect_to root_path if authenticated?
  end

  def create
    email, password = params.expect(:email, :password)
    if user = User.authenticate_by(email: email, password: password)
      if (pending = session.delete(:pending_google_link)) && pending["expires_at"].to_i > Time.current.to_i
        begin
          User.from_google(pending, linking_user: user) if pending.dig("extra", "raw_info", "email") == user.email
        rescue User::InvalidGoogleAccount, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
          flash[:alert] = "Signed in, but Google could not be connected. Please try Google sign-in again."
        end
      end
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
