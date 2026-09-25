Rails.application.routes.draw do
  get "/manifest.json", to: "rails/pwa#manifest", as: :pwa_manifest
  get "/service-worker.js", to: "rails/pwa#service_worker", as: :pwa_service_worker

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
    post "users/invite", to: "users#invite", as: :invite_user
    resources :checkins, only: %i[ index edit update destroy ]
    resources :billing_records, only: :index
    resources :extended_care_schedules, only: %i[ index create update destroy ]
    resources :tasks, only: %i[ index create update destroy ] do
      patch :reorder, on: :collection
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
