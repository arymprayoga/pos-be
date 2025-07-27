require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PosBe
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Security configurations for production readiness

    # API-only application mode for better security
    config.api_only = false # Keep false for ActiveAdmin support

    # Timezone configuration for Indonesian market
    config.time_zone = "Asia/Jakarta"

    # Filter sensitive parameters from logs
    config.filter_parameters += [
      :password, :password_confirmation, :token, :access_token, :refresh_token,
      :secret, :key, :api_key, :auth_token, :jwt, :authorization,
      :credit_card, :cvv, :ccv, :ssn, :social_security_number
    ]

    # Silence deprecation warnings in production
    config.active_support.deprecation = :silence if Rails.env.production?

    # Force SSL in production
    config.force_ssl = Rails.env.production?

    # Disable XML parsing to prevent XXE attacks (Rails 8 may not have XmlParamsParser)
    # config.middleware.delete ActionDispatch::XmlParamsParser if defined?(ActionDispatch::XmlParamsParser)

    # Configure session security
    config.session_store :cookie_store,
      key: "_pos_be_session_#{Rails.env}",
      secure: Rails.env.production?,
      httponly: true,
      same_site: :strict

    # Log level configuration
    config.log_level = Rails.env.production? ? :info : :debug

    # Configure lograge for structured logging
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Json.new
    config.lograge.custom_options = lambda do |event|
      {
        remote_ip: event.payload[:remote_ip],
        user_id: event.payload[:user_id],
        company_id: event.payload[:company_id],
        request_id: event.payload[:request_id]
      }
    end

    # Add custom fields to logs
    config.lograge.custom_payload do |controller|
      {
        remote_ip: controller.request.remote_ip,
        user_id: controller.current_user&.id,
        company_id: controller.request.headers["X-Company-ID"],
        request_id: controller.request.request_id
      }
    end

    # Eager load paths for better performance (not in test environment)
    unless Rails.env.test?
      services_path = Rails.root.join("app", "services")
      extensions_path = Rails.root.join("lib", "extensions")

      config.eager_load_paths << services_path if Dir.exist?(services_path)
      config.eager_load_paths << extensions_path if Dir.exist?(extensions_path)
    end

    # Rate limiting and security middleware order
    config.middleware.insert_before Rack::Runtime, Rack::Attack

    # Configure Active Job queue adapter
    config.active_job.queue_adapter = :solid_queue

    # Configure Active Storage for file uploads (if needed)
    config.active_storage.variant_processor = :image_processing

    # Prevent host header injection
    config.hosts = ENV.fetch("ALLOWED_HOSTS", "").split(",").presence

    # Configure cache store
    if Rails.env.production?
      config.cache_store = :redis_cache_store, {
        url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" },
        namespace: "pos_be_#{Rails.env}_cache",
        expires_in: 1.hour
      }
    end
  end
end
