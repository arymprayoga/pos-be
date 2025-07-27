module AuditLogging
  extend ActiveSupport::Concern

  included do
    before_action :set_audit_context
    after_action :log_user_action, if: :should_log_action?

    attr_accessor :audit_action, :audit_resource_type, :audit_resource_id, :audit_details
  end

  private

  def set_audit_context
    # Set default audit context based on controller and action
    @audit_action = "#{action_name}_#{controller_name.singularize}"
    @audit_resource_type = controller_name.classify
    @audit_resource_id = params[:id]
    @audit_details = {}
  end

  def log_user_action
    return unless current_user && current_company

    begin
      UserAction.log_action(
        user: current_user,
        action: @audit_action,
        resource_type: @audit_resource_type,
        resource_id: @audit_resource_id,
        details: build_audit_details,
        request: request,
        user_session: current_user_session
      )
    rescue => e
      Rails.logger.error "Audit logging failed: #{e.message}"
      # Don't raise - audit failure shouldn't break the main flow
    end
  end

  def log_failed_action(error_message)
    return unless current_company

    UserAction.log_failed_action(
      user: current_user,
      action: @audit_action,
      resource_type: @audit_resource_type,
      error: error_message,
      request: request,
      user_session: current_user_session
    )
  end

  def should_log_action?
    # Don't log read-only actions unless they're sensitive
    return false if %w[index show].include?(action_name) && !sensitive_read_action?

    # Don't log if explicitly disabled
    return false if @audit_disabled

    # Don't log health checks and system endpoints
    return false if controller_name.in?(%w[health system])

    true
  end

  def sensitive_read_action?
    # Define which read actions should be logged
    sensitive_controllers = %w[users reports settings]
    sensitive_actions = %w[export download audit_trail]

    controller_name.in?(sensitive_controllers) ||
      action_name.in?(sensitive_actions)
  end

  def build_audit_details
    details = @audit_details.dup

    # Add request parameters (filtered)
    details[:params] = filtered_params if should_include_params?

    # Add response status
    details[:status] = response.status if response.present?

    # Add company context
    details[:company_id] = current_company.id
    details[:company_name] = current_company.name

    # Add timestamp
    details[:timestamp] = Time.current.iso8601

    details
  end

  def filtered_params
    # Remove sensitive parameters
    filtered = params.except(
      :password, :password_confirmation, :current_password,
      :token, :access_token, :refresh_token,
      :controller, :action, :format
    ).to_unsafe_h

    # Limit size of parameter logging
    filtered.each do |key, value|
      if value.is_a?(String) && value.length > 500
        filtered[key] = "#{value[0..497]}..."
      end
    end

    filtered
  end

  def should_include_params?
    # Include params for create/update actions
    %w[create update destroy].include?(action_name)
  end

  # Helper methods for controllers to customize audit logging

  def set_audit_action(action)
    @audit_action = action
  end

  def set_audit_resource(type, id = nil)
    @audit_resource_type = type
    @audit_resource_id = id
  end

  def add_audit_details(details)
    @audit_details.merge!(details)
  end

  def disable_audit_logging
    @audit_disabled = true
  end

  def enable_audit_logging
    @audit_disabled = false
  end

  # Specific audit methods for common scenarios

  def audit_transaction_void(transaction_id, reason = nil)
    set_audit_action("void_transaction")
    set_audit_resource("Transaction", transaction_id)
    add_audit_details(
      void_reason: reason,
      transaction_id: transaction_id,
      sensitive: true
    )
  end

  def audit_price_override(item_id, original_price, new_price, reason = nil)
    set_audit_action("override_price")
    set_audit_resource("Item", item_id)
    add_audit_details(
      item_id: item_id,
      original_price: original_price,
      new_price: new_price,
      reason: reason,
      price_difference: new_price - original_price,
      sensitive: true
    )
  end

  def audit_inventory_adjustment(item_id, old_quantity, new_quantity, reason = nil)
    set_audit_action("adjust_inventory")
    set_audit_resource("Inventory", item_id)
    add_audit_details(
      item_id: item_id,
      old_quantity: old_quantity,
      new_quantity: new_quantity,
      quantity_change: new_quantity - old_quantity,
      reason: reason,
      sensitive: true
    )
  end

  def audit_role_change(target_user_id, old_role, new_role)
    set_audit_action("change_user_role")
    set_audit_resource("User", target_user_id)
    add_audit_details(
      target_user_id: target_user_id,
      old_role: old_role,
      new_role: new_role,
      sensitive: true
    )
  end

  def audit_permission_change(target_user_id, permission_changes)
    set_audit_action("change_user_permissions")
    set_audit_resource("User", target_user_id)
    add_audit_details(
      target_user_id: target_user_id,
      permission_changes: permission_changes,
      sensitive: true
    )
  end

  def audit_login_attempt(email, success, failure_reason = nil)
    action = success ? "login_success" : "login_failure"
    set_audit_action(action)
    set_audit_resource("Authentication", nil)
    add_audit_details(
      email: email,
      success: success,
      failure_reason: failure_reason,
      sensitive: true
    )
  end

  def audit_data_export(export_type, record_count = nil)
    set_audit_action("export_data")
    set_audit_resource("Report", nil)
    add_audit_details(
      export_type: export_type,
      record_count: record_count,
      sensitive: true
    )
  end
end
