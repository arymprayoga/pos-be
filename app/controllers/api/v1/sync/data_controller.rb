class Api::V1::Sync::DataController < Api::V1::BaseController
  before_action :validate_sync_permissions!

  # GET /api/v1/sync/delta
  # Retrieves incremental changes since the last sync
  def delta
    last_sync_at = parse_timestamp(params[:last_sync_at])

    unless last_sync_at
      render_error("last_sync_at parameter is required and must be a valid timestamp", :bad_request)
      return
    end

    delta_data = SyncService.get_delta_changes(
      company: current_company,
      last_sync_at: last_sync_at,
      resource_types: params[:resource_types]&.split(",")
    )

    render_success({
      delta: delta_data,
      sync_timestamp: Time.current.iso8601,
      next_sync_token: generate_sync_token
    })
  end

  # POST /api/v1/sync/full
  # Performs a complete data refresh for offline clients
  def full_refresh
    # Validate client can perform full refresh
    unless current_user.can?(:perform_full_sync)
      render_error("Not authorized to perform full data refresh", :forbidden)
      return
    end

    # Optional: Limit full refresh frequency
    if rate_limited_full_refresh?
      render_error("Full refresh rate limit exceeded. Please wait before requesting again.", :too_many_requests)
      return
    end

    full_data = SyncService.get_full_dataset(
      company: current_company,
      user: current_user,
      resource_types: params[:resource_types]&.split(","),
      options: {
        include_deleted: params[:include_deleted] == "true",
        limit_records: params[:limit]&.to_i
      }
    )

    # Log full refresh for monitoring
    log_full_refresh_request

    render_success({
      data: full_data,
      sync_timestamp: Time.current.iso8601,
      sync_token: generate_sync_token,
      total_records: calculate_total_records(full_data)
    })
  end

  # GET /api/v1/sync/status
  # Returns synchronization status and statistics
  def status
    sync_status = SyncService.get_sync_status(
      company: current_company,
      user: current_user
    )

    render_success(sync_status)
  end

  # POST /api/v1/sync/acknowledge
  # Acknowledges successful synchronization of specific data
  def acknowledge
    sync_token = params[:sync_token]
    acknowledged_resources = params[:acknowledged_resources] || []

    unless sync_token.present?
      render_error("sync_token is required", :bad_request)
      return
    end

    result = SyncService.acknowledge_sync(
      company: current_company,
      user: current_user,
      sync_token: sync_token,
      acknowledged_resources: acknowledged_resources
    )

    if result[:success]
      render_success(result[:data], "Synchronization acknowledged successfully")
    else
      render_error(result[:error], :unprocessable_entity)
    end
  end

  # GET /api/v1/sync/conflicts
  # Returns any data conflicts that need resolution
  def conflicts
    conflicts = SyncService.get_pending_conflicts(
      company: current_company,
      user: current_user
    )

    render_success({
      conflicts: conflicts,
      conflict_count: conflicts.size,
      resolution_strategies: SyncService::CONFLICT_RESOLUTION_STRATEGIES
    })
  end

  # POST /api/v1/sync/resolve_conflicts
  # Resolves data conflicts with specified strategy
  def resolve_conflicts
    conflict_resolutions = params[:resolutions] || []

    if conflict_resolutions.empty?
      render_error("No conflict resolutions provided", :bad_request)
      return
    end

    result = SyncService.resolve_conflicts(
      company: current_company,
      user: current_user,
      resolutions: conflict_resolutions
    )

    if result[:success]
      render_success(result[:data], "Conflicts resolved successfully")
    else
      render_error(result[:error], :unprocessable_entity)
    end
  end

  # GET /api/v1/sync/health
  # Health check for sync service
  def health
    health_status = {
      status: "healthy",
      timestamp: Time.current.iso8601,
      company_id: current_company.id,
      sync_service_version: SyncService::VERSION,
      database_connection: database_healthy?,
      redis_connection: redis_healthy?,
      last_successful_sync: get_last_successful_sync
    }

    overall_status = health_status.values_at(:database_connection, :redis_connection).all? ? :ok : :service_unavailable

    render json: health_status, status: overall_status
  end

  private

  def validate_sync_permissions!
    unless current_user.can?(:sync_data)
      render_error("Not authorized to perform data synchronization", :forbidden)
      false
    end
  end

  def parse_timestamp(timestamp_param)
    return nil if timestamp_param.blank?

    Time.zone.parse(timestamp_param)
  rescue ArgumentError
    nil
  end

  def generate_sync_token
    # Generate a unique token for this sync session
    "sync_#{current_company.id}_#{current_user.id}_#{Time.current.to_i}_#{SecureRandom.hex(8)}"
  end

  def rate_limited_full_refresh?
    # Check if user has performed full refresh recently
    cache_key = "full_refresh_rate_limit:#{current_company.id}:#{current_user.id}"
    last_refresh = Rails.cache.read(cache_key)

    if last_refresh && last_refresh > 1.hour.ago
      true
    else
      Rails.cache.write(cache_key, Time.current, expires_in: 1.hour)
      false
    end
  end

  def calculate_total_records(data)
    return 0 unless data.is_a?(Hash)

    data.values.sum do |resource_data|
      resource_data.is_a?(Array) ? resource_data.size : 0
    end
  end

  def log_full_refresh_request
    UserAction.log_action(
      user: current_user,
      action_type: :sync,
      resource_type: "FullRefresh",
      resource_id: current_company.id,
      details: {
        action: "full_refresh_requested",
        resource_types: params[:resource_types],
        include_deleted: params[:include_deleted],
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      }
    )
  end

  def database_healthy?
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue
    false
  end

  def redis_healthy?
    Rails.cache.redis.ping == "PONG"
    true
  rescue
    false
  end

  def get_last_successful_sync
    # This would come from a sync log table if implemented
    cache_key = "last_successful_sync:#{current_company.id}:#{current_user.id}"
    Rails.cache.read(cache_key)
  end
end
