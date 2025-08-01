# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Rails.env.development? ? [ "localhost:3001", "localhost:3000" ] : ENV.fetch("ALLOWED_ORIGINS", "").split(",")

    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end

  # Allow ActiveAdmin to work
  allow do
    origins Rails.env.development? ? [ "localhost:3000" ] : ENV.fetch("ADMIN_ORIGINS", "").split(",")

    resource "/admin/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end
end
