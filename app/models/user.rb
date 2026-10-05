class User < ApplicationRecord
  class InvalidGoogleAccount < StandardError; end
  class GoogleLinkRequired < StandardError; end
  has_many :school_year_rollovers
  has_secure_password reset_token: { expires_in: 7.days }
  has_many :sessions, dependent: :destroy

  enum :role, { admin: "Admin", user: "User" }, default: :user, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  # Only call with the auth hash supplied by OmniAuth, never request parameters.
  def self.from_google(auth, linking_user: nil)
    raise InvalidGoogleAccount unless auth&.dig("provider") == "google_oauth2"

    info = auth.dig("extra", "raw_info") || {}
    uid = auth["uid"].to_s
    email = info["email"].to_s.strip.downcase
    raise InvalidGoogleAccount unless uid.present? && email.present? && info["sub"].to_s == uid && info["email_verified"] == true

    transaction do
      user = find_by(google_uid: uid)
      return user if user

      user = find_by(email: email)
      if user
        user.with_lock do
          raise InvalidGoogleAccount if user.google_uid.present?
          authoritative_email = email.end_with?("@gmail.com") || info["hd"].present?
          raise GoogleLinkRequired unless authoritative_email || linking_user&.id == user.id

          user.update!(google_uid: uid)
        end
        user
      else
        create!(email: email, google_uid: uid, password: SecureRandom.base58(32), role: :user)
      end
    end
  end
end
