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

      # User management (Phase 2.2)
      resources :users do
        member do
          patch :change_role
          patch :manage_permissions
          get :sessions
          delete "sessions/:session_token", to: "users#terminate_session", as: :terminate_session
        end
      end

      # Core resources
      resources :companies, only: [ :show, :update ]
      resources :categories
      resources :products do
        member do
          post :add_variant
          delete "variants/:variant_type", to: "products#remove_variant", as: :remove_variant
          get :variant_combinations
        end
      end
      # resources :transactions # To be implemented in Phase 3.2
    end
  end

  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root route redirects to admin
  root to: redirect("/admin")
end
