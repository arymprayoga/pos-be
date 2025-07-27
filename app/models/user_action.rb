class UserAction < ApplicationRecord
  acts_as_tenant
  belongs_to :company
  belongs_to :user, optional: true
  belongs_to :user_session, optional: true

  validates :action, presence: true
  validates :resource_type, presence: true
  validates :ip_address, presence: true
  validates :user_agent, presence: true

  # Action types for categorization
  ACTION_TYPES = {
    authentication: %w[login logout refresh_token password_change],
    transactions: %w[create_transaction void_transaction override_price apply_discount],
    inventory: %w[update_stock create_item update_item delete_item stock_adjustment],
    reports: %w[view_report export_report daily_summary monthly_summary],
    user_management: %w[create_user update_user delete_user assign_role remove_role],
    settings: %w[update_settings manage_payment_methods manage_taxes update_company],
    categories: %w[create_category update_category delete_category],
    system: %w[data_sync backup_restore system_maintenance]
  }.freeze

  # Sensitive actions that require special attention
  SENSITIVE_ACTIONS = %w[
    void_transaction override_price delete_item delete_user assign_role
    remove_role update_settings backup_restore system_maintenance
  ].freeze

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_action, ->(action) { where(action: action) }
  scope :for_resource, ->(resource_type) { where(resource_type: resource_type) }
  scope :sensitive, -> { where(action: SENSITIVE_ACTIONS) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :today, -> { where(created_at: Date.current.beginning_of_day..Date.current.end_of_day) }

  def self.log_action(user:, action:, resource_type:, resource_id: nil, details: {}, request: nil, user_session: nil)
    create!(
      company: user.company,
      user: user,
      user_session: user_session,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      details: sanitize_details(details),
      ip_address: extract_ip_address(request),
      user_agent: extract_user_agent(request),
      success: true
    )
  rescue => e
    Rails.logger.error "Failed to log user action: #{e.message}"
    # Don't raise error to avoid disrupting main flow
    nil
  end

  def self.log_failed_action(user:, action:, resource_type:, error:, request: nil, user_session: nil)
    create!(
      company: user&.company,
      user: user,
      user_session: user_session,
      action: action,
      resource_type: resource_type,
      details: { error: error.to_s },
      ip_address: extract_ip_address(request),
      user_agent: extract_user_agent(request),
      success: false
    )
  rescue => e
    Rails.logger.error "Failed to log failed action: #{e.message}"
    nil
  end

  def self.audit_trail_for_resource(resource_type, resource_id, limit: 50)
    where(resource_type: resource_type, resource_id: resource_id)
      .includes(:user)
      .recent
      .limit(limit)
  end

  def self.user_activity_summary(user, date_range = 7.days.ago..Time.current)
    actions = for_user(user).by_date_range(date_range.begin, date_range.end)

    {
      total_actions: actions.count,
      successful_actions: actions.where(success: true).count,
      failed_actions: actions.where(success: false).count,
      sensitive_actions: actions.sensitive.count,
      most_common_actions: actions.group(:action).count.sort_by { |_, count| -count }.first(5),
      daily_activity: actions.group("DATE(created_at)").count
    }
  end

  def sensitive?
    SENSITIVE_ACTIONS.include?(action)
  end

  def action_category
    ACTION_TYPES.find { |_, actions| actions.include?(action) }&.first || :other
  end

  def formatted_details
    return {} unless details.present?

    details.except("password", "password_confirmation", "token", "secret")
  end

  def action_summary
    base = "#{user.name} #{action.humanize.downcase}"

    if resource_id.present?
      "#{base} #{resource_type.humanize.downcase} ##{resource_id}"
    else
      "#{base} #{resource_type.humanize.downcase}"
    end
  end

  private

  def self.sanitize_details(details)
    return {} unless details.is_a?(Hash)

    # Remove sensitive information
    sanitized = details.deep_dup

    # Remove password fields
    sanitized.delete("password")
    sanitized.delete("password_confirmation")
    sanitized.delete("current_password")

    # Remove token fields
    sanitized.delete("token")
    sanitized.delete("access_token")
    sanitized.delete("refresh_token")
    sanitized.delete("jwt")

    # Remove other sensitive fields
    sanitized.delete("secret")
    sanitized.delete("api_key")

    # Truncate long text fields
    sanitized.each do |key, value|
      if value.is_a?(String) && value.length > 1000
        sanitized[key] = "#{value[0..997]}..."
      end
    end

    sanitized
  end

  def self.extract_ip_address(request)
    return "unknown" unless request.present?

    request.remote_ip || request.ip || "unknown"
  end

  def self.extract_user_agent(request)
    return "unknown" unless request.present?

    request.user_agent&.truncate(255) || "unknown"
  end
end
