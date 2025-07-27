Rails.application.configure do
  # Enable Lograge
  config.lograge.enabled = true

  # Add custom data to logs
  config.lograge.custom_options = lambda do |event|
    {
      time: Time.current.iso8601,
      user_id: event.payload[:user_id],
      company_id: event.payload[:company_id],
      request_id: event.payload[:request_id],
      ip: event.payload[:ip]
    }.compact
  end

  # Configure log format
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Filter sensitive parameters from logs
  config.lograge.custom_payload do |controller|
    payload = {
      request_id: controller.request.request_id,
      ip: controller.request.remote_ip
    }

    # Only add user data if controller responds to current_user
    if controller.respond_to?(:current_user) && controller.current_user
      payload[:user_id] = controller.current_user.id
      payload[:company_id] = controller.current_user.company_id
    end

    payload
  end

  # Exclude health check endpoints from logs
  config.lograge.ignore_actions = [ "HealthController#index" ]
end
