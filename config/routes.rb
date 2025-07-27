Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  # Performance monitoring dashboard
  mount RailsPerformance::Engine, at: "/admin/performance" if defined?(RailsPerformance)

  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication
      post "/auth/login", to: "auth#login"
      post "/auth/refresh", to: "auth#refresh"
      delete "/auth/logout", to: "auth#logout"
      delete "/auth/logout_all", to: "auth#logout_all"

      # Sync endpoints
      namespace :sync do
        post "/transactions", to: "transactions#create"
        get "/delta", to: "data#delta"
        post "/full", to: "data#full_refresh"
        get "/status", to: "data#status"
      end

      # Core resources (to be implemented in later phases)
      # resources :companies, only: [:show, :update]
      # resources :categories
      # resources :products
      # resources :transactions
      # resources :users
    end
  end

  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root route redirects to admin
  root "admin/dashboard#index"
end
