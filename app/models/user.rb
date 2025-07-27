class User < ApplicationRecord
  include Authorizable
  include SoftDeletable
  include Auditable

  acts_as_tenant
  belongs_to :company
  has_many :user_sessions, dependent: :destroy
  has_many :user_actions, dependent: :destroy
  has_many :refresh_tokens, dependent: :destroy

  has_secure_password

  enum :role, { cashier: 0, manager: 1, owner: 2 }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { scope: :company_id, conditions: -> { where(deleted_at: nil) } }
  validates :role, presence: true

  scope :active, -> { where(active: true) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  after_create :setup_default_permissions
  after_update :handle_role_change, if: :saved_change_to_role?

  def session_manager
    @session_manager ||= SessionManager.new(self)
  end

  def active_sessions
    user_sessions.active
  end

  def session_count
    active_sessions.count
  end

  def last_login_at
    user_sessions.order(:created_at).last&.created_at
  end

  def last_activity_at
    user_sessions.active.maximum(:last_activity_at) || last_login_at
  end

  def recent_actions(limit: 10)
    user_actions.recent.limit(limit).includes(:user_session)
  end

  def deactivate!
    transaction do
      update!(active: false, updated_by: current_user&.id)
      session_manager.terminate_all_sessions
    end
  end

  def activate!
    update!(active: true, updated_by: current_user&.id)
  end

  def change_password!(new_password, current_password = nil)
    if current_password.present?
      unless authenticate(current_password)
        errors.add(:current_password, "is incorrect")
        return false
      end
    end

    transaction do
      update!(password: new_password, updated_by: current_user&.id)
      # Terminate all sessions except current one to force re-login
      session_manager.terminate_all_sessions
    end
  end

  def role_display_name
    role.humanize
  end

  def permission_summary
    {
      role: role,
      custom_permissions: permissions.count,
      can_manage_inventory: can_manage_inventory?,
      can_access_reports: can_access_reports?,
      can_void_transactions: can_void_transactions?,
      can_override_prices: can_override_prices?,
      can_manage_users: can_manage_users?,
      can_assign_roles: can_assign_roles?,
      can_access_settings: can_access_settings?,
      can_manage_settings: can_manage_settings?
    }
  end

  def activity_summary(days = 7)
    date_range = days.days.ago..Time.current
    actions = user_actions.by_date_range(date_range.begin, date_range.end)

    {
      total_actions: actions.count,
      successful_actions: actions.where(success: true).count,
      failed_actions: actions.where(success: false).count,
      sensitive_actions: actions.sensitive.count,
      login_count: actions.where(action: "login_success").count,
      last_login: last_login_at,
      last_activity: last_activity_at,
      active_sessions: session_count
    }
  end

  def security_summary
    {
      password_last_changed: updated_at, # Assuming password changes update the record
      active_sessions: session_count,
      last_login: last_login_at,
      last_activity: last_activity_at,
      failed_login_attempts: user_actions.where(action: "login_failure")
                                        .where("created_at > ?", 24.hours.ago)
                                        .count,
      recent_ip_addresses: user_sessions.where("created_at > ?", 7.days.ago)
                                       .distinct
                                       .pluck(:ip_address)
                                       .compact
    }
  end

  private

  def setup_default_permissions
    # Create system permissions for company if they don't exist
    Permission.create_system_permissions_for_company(company)

    # Grant default permissions for the user's role
    grant_role_permissions!(role)
  end

  def handle_role_change
    # When role changes, update permissions accordingly
    revoke_all_permissions!
    grant_role_permissions!(role)
  end
end
