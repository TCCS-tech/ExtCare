class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  enum :role, { admin: "Admin", user: "User" }, default: :user, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }
end
