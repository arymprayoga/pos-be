class Api::V1::Sync::TransactionsController < Api::V1::BaseController
  before_action :validate_sync_permissions!

  # POST /api/v1/sync/transactions
  # Bulk upload transactions from offline POS systems
  def create
    transaction_data = params[:transactions] || []

    if transaction_data.empty?
      render_error("No transactions provided for sync", :bad_request)
      return
    end

    # Validate bulk size
    if transaction_data.size > max_bulk_size
      render_error("Bulk size exceeds maximum allowed (#{max_bulk_size})", :payload_too_large)
      return
    end

    # Process transactions in batches
    result = SyncService.process_bulk_transactions(
      company: current_company,
      user: current_user,
      transactions: transaction_data,
      options: {
        client_timestamp: params[:client_timestamp],
        device_id: params[:device_id],
        sync_token: params[:sync_token]
      }
    )

    if result[:success]
      log_bulk_transaction_sync(result)
      render_success(result[:data], "Transactions synchronized successfully")
    else
      render_error(result[:error], :unprocessable_entity, result[:errors] || [])
    end
  end

  # GET /api/v1/sync/transactions/status
  # Check status of previous transaction sync operations
  def status
    sync_status = SyncService.get_transaction_sync_status(
      company: current_company,
      user: current_user,
      device_id: params[:device_id]
    )

    render_success(sync_status)
  end

  # POST /api/v1/sync/transactions/validate
  # Validate transaction data before actual sync
  def validate
    transaction_data = params[:transactions] || []

    if transaction_data.empty?
      render_error("No transactions provided for validation", :bad_request)
      return
    end

    validation_result = SyncService.validate_bulk_transactions(
      company: current_company,
      transactions: transaction_data
    )

    render_success({
      valid: validation_result[:valid],
      total_transactions: transaction_data.size,
      valid_transactions: validation_result[:valid_count],
      invalid_transactions: validation_result[:invalid_count],
      validation_errors: validation_result[:errors],
      estimated_processing_time: estimate_processing_time(transaction_data.size)
    })
  end

  # POST /api/v1/sync/transactions/retry
  # Retry failed transaction syncs
  def retry
    failed_sync_ids = params[:failed_sync_ids] || []

    if failed_sync_ids.empty?
      render_error("No failed sync IDs provided", :bad_request)
      return
    end

    result = SyncService.retry_failed_transactions(
      company: current_company,
      user: current_user,
      failed_sync_ids: failed_sync_ids
    )

    if result[:success]
      render_success(result[:data], "Failed transactions retry initiated")
    else
      render_error(result[:error], :unprocessable_entity)
    end
  end

  # GET /api/v1/sync/transactions/conflicts
  # Get transaction conflicts that need manual resolution
  def conflicts
    conflicts = SyncService.get_transaction_conflicts(
      company: current_company,
      user: current_user
    )

    render_success({
      conflicts: conflicts,
      conflict_count: conflicts.size,
      auto_resolvable: conflicts.count { |c| c[:auto_resolvable] },
      manual_resolution_required: conflicts.count { |c| !c[:auto_resolvable] }
    })
  end

  # POST /api/v1/sync/transactions/resolve_conflicts
  # Resolve transaction conflicts
  def resolve_conflicts
    conflict_resolutions = params[:resolutions] || []

    result = SyncService.resolve_transaction_conflicts(
      company: current_company,
      user: current_user,
      resolutions: conflict_resolutions
    )

    if result[:success]
      render_success(result[:data], "Transaction conflicts resolved")
    else
      render_error(result[:error], :unprocessable_entity)
    end
  end

  # DELETE /api/v1/sync/transactions/cleanup
  # Clean up old sync records and temporary data
  def cleanup
    days_to_keep = params[:days]&.to_i || 30

    unless current_user.can?(:manage_sync_cleanup)
      render_error("Not authorized to perform sync cleanup", :forbidden)
      return
    end

    result = SyncService.cleanup_transaction_sync_data(
      company: current_company,
      days_to_keep: days_to_keep
    )

    if result[:success]
      render_success(result[:data], "Sync data cleanup completed")
    else
      render_error(result[:error], :unprocessable_entity)
    end
  end

  # GET /api/v1/sync/transactions/statistics
  # Get transaction sync statistics and metrics
  def statistics
    date_range = parse_date_range

    stats = SyncService.get_transaction_sync_statistics(
      company: current_company,
      date_range: date_range,
      user: current_user
    )

    render_success(stats)
  end

  private

  def validate_sync_permissions!
    unless current_user.can?(:sync_transactions)
      render_error("Not authorized to sync transactions", :forbidden)
      false
    end
  end

  def max_bulk_size
    # Maximum number of transactions per bulk request
    (Rails.application.config.sync_max_bulk_size || 100).to_i
  end

  def estimate_processing_time(transaction_count)
    # Rough estimate: 100ms per transaction for processing
    base_time = transaction_count * 0.1
    # Add overhead for validation and database operations
    overhead = [ transaction_count * 0.05, 2.0 ].min

    (base_time + overhead).round(2)
  end

  def parse_date_range
    return nil unless params[:start_date].present? && params[:end_date].present?

    start_date = Date.parse(params[:start_date]).beginning_of_day
    end_date = Date.parse(params[:end_date]).end_of_day
    start_date..end_date
  rescue Date::Error
    nil
  end

  def log_bulk_transaction_sync(result)
    UserAction.log_action(
      user: current_user,
      action_type: :sync,
      resource_type: "BulkTransactionSync",
      resource_id: current_company.id,
      details: {
        action: "bulk_transactions_synced",
        total_transactions: result[:data][:total_transactions],
        successful_syncs: result[:data][:successful_syncs],
        failed_syncs: result[:data][:failed_syncs],
        processing_time: result[:data][:processing_time],
        device_id: params[:device_id],
        sync_token: params[:sync_token],
        client_timestamp: params[:client_timestamp]
      }
    )
  end
end
