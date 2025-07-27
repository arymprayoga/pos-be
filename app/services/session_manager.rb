class SessionManager
  class SessionError < StandardError; end
  class SessionExpiredError < SessionError; end
  class SessionLimitExceededError < SessionError; end
  class InvalidSessionError < SessionError; end

  def initialize(user)
    @user = user
    @company = user.company
  end

  def create_session(device_fingerprint:, ip_address:, user_agent:)
    # Check if user is active
    raise SessionError, "User account is inactive" unless @user.active?

    # Generate unique session token
    session_token = generate_session_token

    # Create session record
    session = UserSession.create!(
      company: @company,
      user: @user,
      session_token: session_token,
      device_fingerprint: device_fingerprint,
      ip_address: ip_address,
      user_agent: user_agent
    )

    # Log session creation
    UserAction.log_action(
      user: @user,
      action: "create_session",
      resource_type: "UserSession",
      resource_id: session.id,
      details: {
        device_fingerprint: device_fingerprint,
        ip_address: ip_address,
        user_agent: user_agent&.truncate(100)
      }
    )

    session
  rescue ActiveRecord::RecordInvalid => e
    raise SessionError, "Failed to create session: #{e.message}"
  end

  def find_active_session(session_token)
    session = UserSession.find_active_session(session_token)
    raise InvalidSessionError, "Session not found or inactive" unless session

    # Check if session belongs to the user
    raise InvalidSessionError, "Session does not belong to user" unless session.user_id == @user.id

    session
  end

  def refresh_session(session_token)
    session = find_active_session(session_token)

    # Check if session is about to expire (within 1 hour)
    if session.time_until_expiry < 1.hour
      session.refresh_activity!

      UserAction.log_action(
        user: @user,
        action: "refresh_session",
        resource_type: "UserSession",
        resource_id: session.id,
        details: {
          new_expiry: session.expired_at,
          time_remaining: session.time_until_expiry
        },
        user_session: session
      )
    else
      # Just update last activity
      session.update!(last_activity_at: Time.current)
    end

    session
  rescue InvalidSessionError, SessionExpiredError
    # Clean up expired session
    UserSession.find_by(session_token: session_token)&.expire!
    raise
  end

  def terminate_session(session_token)
    session = UserSession.find_by(session_token: session_token)
    return false unless session && session.user_id == @user.id

    session.logout!

    UserAction.log_action(
      user: @user,
      action: "terminate_session",
      resource_type: "UserSession",
      resource_id: session.id,
      details: {
        device_fingerprint: session.device_fingerprint,
        session_duration: Time.current - session.created_at
      },
      user_session: session
    )

    true
  end

  def terminate_all_sessions(except_session: nil)
    sessions = UserSession.for_user(@user).active
    sessions = sessions.where.not(id: except_session.id) if except_session

    terminated_count = 0
    sessions.each do |session|
      session.logout!
      terminated_count += 1
    end

    UserAction.log_action(
      user: @user,
      action: "terminate_all_sessions",
      resource_type: "UserSession",
      details: {
        sessions_terminated: terminated_count,
        kept_session_id: except_session&.id
      },
      user_session: except_session
    )

    terminated_count
  end

  def terminate_other_sessions(current_session)
    terminate_all_sessions(except_session: current_session)
  end

  def list_active_sessions
    UserSession.for_user(@user)
               .active
               .order(last_activity_at: :desc)
               .map(&:session_info)
  end

  def session_analytics(date_range = 30.days.ago..Time.current)
    sessions = UserSession.for_user(@user)
                         .where(created_at: date_range)

    {
      total_sessions: sessions.count,
      active_sessions: sessions.active.count,
      expired_sessions: sessions.expired.count,
      average_session_duration: calculate_average_duration(sessions),
      unique_devices: sessions.distinct.count(:device_fingerprint),
      unique_ips: sessions.distinct.count(:ip_address),
      sessions_by_day: sessions.group("DATE(created_at)").count,
      most_used_devices: sessions.group(:device_fingerprint).count.sort_by { |_, count| -count }.first(5)
    }
  end

  def cleanup_expired_sessions
    expired_sessions = UserSession.for_user(@user).expired
    count = expired_sessions.count
    expired_sessions.delete_all

    UserAction.log_action(
      user: @user,
      action: "cleanup_expired_sessions",
      resource_type: "UserSession",
      details: {
        cleaned_sessions: count
      }
    ) if count > 0

    count
  end

  def validate_session_security(session, ip_address, user_agent)
    warnings = []

    # Check for IP address changes
    if session.ip_address != ip_address
      warnings << {
        type: "ip_change",
        message: "IP address changed during session",
        old_ip: session.ip_address,
        new_ip: ip_address
      }
    end

    # Check for user agent changes (major changes only)
    if !user_agents_similar?(session.user_agent, user_agent)
      warnings << {
        type: "user_agent_change",
        message: "User agent changed significantly during session",
        old_agent: session.user_agent&.truncate(100),
        new_agent: user_agent&.truncate(100)
      }
    end

    # Check session age
    if session.created_at < 24.hours.ago
      warnings << {
        type: "long_session",
        message: "Session has been active for more than 24 hours",
        session_age: Time.current - session.created_at
      }
    end

    # Log security warnings
    if warnings.any?
      UserAction.log_action(
        user: @user,
        action: "session_security_warning",
        resource_type: "UserSession",
        resource_id: session.id,
        details: {
          warnings: warnings,
          ip_address: ip_address,
          user_agent: user_agent&.truncate(100)
        },
        user_session: session
      )
    end

    warnings
  end

  def force_expire_session(session_token, reason = nil)
    session = UserSession.find_by(session_token: session_token)
    return false unless session && session.user_id == @user.id

    session.expire!

    UserAction.log_action(
      user: @user,
      action: "force_expire_session",
      resource_type: "UserSession",
      resource_id: session.id,
      details: {
        reason: reason,
        expired_by: "system"
      }
    )

    true
  end

  private

  def generate_session_token
    loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless UserSession.exists?(session_token: token)
    end
  end

  def calculate_average_duration(sessions)
    completed_sessions = sessions.where.not(logged_out_at: nil)
    return 0 if completed_sessions.empty?

    total_duration = completed_sessions.sum do |session|
      (session.logged_out_at - session.created_at).to_i
    end

    total_duration / completed_sessions.count
  end

  def user_agents_similar?(agent1, agent2)
    return true if agent1 == agent2
    return false if agent1.blank? || agent2.blank?

    # Extract browser and version info for comparison
    # This is a simple comparison - could be made more sophisticated
    browser1 = extract_browser_info(agent1)
    browser2 = extract_browser_info(agent2)

    browser1[:browser] == browser2[:browser] && browser1[:platform] == browser2[:platform]
  end

  def extract_browser_info(user_agent)
    return { browser: "unknown", platform: "unknown" } if user_agent.blank?

    browser = case user_agent
    when /Chrome/i then "Chrome"
    when /Firefox/i then "Firefox"
    when /Safari/i then "Safari"
    when /Edge/i then "Edge"
    else "Other"
    end

    platform = case user_agent
    when /Windows/i then "Windows"
    when /Mac/i then "Mac"
    when /Linux/i then "Linux"
    when /Android/i then "Android"
    when /iOS/i then "iOS"
    else "Other"
    end

    { browser: browser, platform: platform }
  end
end
