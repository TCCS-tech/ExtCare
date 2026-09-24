Rails.application.routes.draw do
  root "home#show"

  resource :session
  resources :passwords, param: :token
  resources :checkins, only: %i[ index create ]
  resources :checkouts, only: %i[ index create update ]

  namespace :admin do
    root "dashboard#show"
    post "clear_attendance", to: "dashboard#clear_attendance", as: :clear_attendance
    resources :students, only: %i[ index new create edit update ]
    resources :users, only: %i[ index create update ]
    resources :checkins, only: %i[ index edit update destroy ]
    resources :billing_records, only: :index
    resources :extended_care_schedules, only: %i[ index create update destroy ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
