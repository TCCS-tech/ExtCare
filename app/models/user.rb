class User < ApplicationRecord
  has_secure_password reset_token: { expires_in: 7.days }
  has_many :sessions, dependent: :destroy

  enum :role, { admin: "Admin", user: "User" }, default: :user, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
end
