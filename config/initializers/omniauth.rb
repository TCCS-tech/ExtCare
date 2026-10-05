Rails.application.config.x.google_sign_in_enabled =
  ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.logger = Rails.logger

if Rails.application.config.x.google_sign_in_enabled
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, ENV.fetch("GOOGLE_CLIENT_ID"), ENV.fetch("GOOGLE_CLIENT_SECRET"),
      callback_path: "/api/auth/callback/google",
      scope: "openid,email", access_type: "online", prompt: "select_account",
      overridable_authorize_options: []
  end
end
