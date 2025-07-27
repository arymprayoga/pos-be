class UserSession < ApplicationRecord
  acts_as_tenant
  belongs_to :company
  belongs_to :user

  validates :session_token, presence: true, uniqueness: true
  validates :device_fingerprint, presence: true
  validates :ip_address, presence: true
  validates :user_agent, presence: true

  scope :active, -> { where(logged_out_at: nil).where("expired_at IS NULL OR expired_at > ?", Time.current) }
  scope :expired, -> { where("expired_at IS NOT NULL AND expired_at < ?", Time.current) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_device, ->(fingerprint) { where(device_fingerprint: fingerprint) }

  # Session timeout configurations by role
  SESSION_TIMEOUTS = {
    "cashier" => 8.hours,
    "manager" => 12.hours,
    "owner" => 24.hours
  }.freeze

  # Maximum concurrent sessions by role
  MAX_SESSIONS = {
    "cashier" => 2,
    "manager" => 3,
    "owner" => 5
  }.freeze

  before_create :set_expires_at
  before_create :cleanup_old_sessions
  before_create :enforce_session_limits

  def self.find_active_session(token)
    active.find_by(session_token: token)
  end

  def self.cleanup_expired_sessions
    where("expired_at < ? OR created_at < ?", Time.current, 30.days.ago).delete_all
  end

  def self.revoke_all_for_user(user)
    for_user(user).active.update_all(
      logged_out_at: Time.current,
      expired_at: Time.current
    )
  end

  def active?
    !expired? && !logged_out?
  end

  def expired?
    expired_at.present? && expired_at < Time.current
  end

  def logged_out?
    logged_out_at.present?
  end

  def expire!
    update!(expired_at: Time.current)
  end

  def logout!
    update!(logged_out_at: Time.current, expired_at: Time.current)
  end

  def refresh_activity!
    return unless active?

    update!(
      last_activity_at: Time.current,
      expired_at: calculate_expiry_time
    )
  end

  def time_until_expiry
    return 0 unless active? && expired_at.present?

    [ expired_at - Time.current, 0 ].max
  end

  def session_info
    {
      id: id,
      device_fingerprint: device_fingerprint,
      ip_address: ip_address,
      user_agent: user_agent,
      created_at: created_at,
      last_activity_at: last_activity_at,
      expires_at: expired_at,
      active: active?
    }
  end

  private

  def set_expires_at
    self.expired_at = calculate_expiry_time
    self.last_activity_at = Time.current
  end

  def calculate_expiry_time
    timeout = SESSION_TIMEOUTS[user.role] || SESSION_TIMEOUTS["cashier"]
    Time.current + timeout
  end

  def cleanup_old_sessions
    # Remove expired sessions for this user
    UserSession.for_user(user).expired.delete_all
  end

  def enforce_session_limits
    max_sessions = MAX_SESSIONS[user.role] || MAX_SESSIONS["cashier"]
    active_sessions = UserSession.for_user(user).active.count

    if active_sessions >= max_sessions
      # Remove oldest sessions
      oldest_sessions = UserSession.for_user(user)
                                  .active
                                  .order(:last_activity_at)
                                  .limit(active_sessions - max_sessions + 1)

      oldest_sessions.each(&:expire!)
    end
  end
end
