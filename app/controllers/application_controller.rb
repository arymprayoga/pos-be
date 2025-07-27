class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  # Admin security methods for ActiveAdmin
  def log_admin_action
    return unless controller_name.start_with?("admin")

    Rails.logger.info({
      admin_action: "started",
      controller: controller_name,
      action: action_name,
      admin_user: current_admin_user&.email,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      timestamp: Time.current
    }.to_json)
  end

  def audit_admin_action
    return unless controller_name.start_with?("admin")

    Rails.logger.info({
      admin_action: "completed",
      controller: controller_name,
      action: action_name,
      admin_user: current_admin_user&.email,
      ip_address: request.remote_ip,
      response_status: response.status,
      timestamp: Time.current
    }.to_json)
  end

  def access_denied
    render file: "#{Rails.root}/public/403.html", status: :forbidden, layout: false
  end
end
