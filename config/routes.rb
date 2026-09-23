Rails.application.routes.draw do
  root "home#show"

  resource :session
  resources :passwords, param: :token
  resources :checkins, only: %i[ index create ]
  resources :checkouts, only: %i[ index create ]

  namespace :admin do
    root "dashboard#show"
    resources :students, only: %i[ index new create edit update ]
    resources :checkins, only: :index
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
