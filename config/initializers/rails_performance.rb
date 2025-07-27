# Rails Performance monitoring configuration for POS Backend
if defined?(RailsPerformance)
  RailsPerformance.setup do |config|
    # Enable/disable performance tracking
    config.enabled = true

    # Duration to store performance data (in seconds)
    # Keep 7 days of data for analysis
    config.duration = 7.days.to_i

    # Redis configuration for storing performance data
    config.redis = Redis.new(
      url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/3" }
    )
  end

  # Mount the performance dashboard at /admin/performance for internal use
  Rails.application.routes.append do
    mount RailsPerformance::Engine, at: "/admin/performance"
  end

  # Disable performance tracking in test environment
  if Rails.env.test?
    RailsPerformance.setup do |config|
      config.enabled = false
    end
  end
end
