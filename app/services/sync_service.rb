class SyncService
  VERSION = "1.0.0"

  # Conflict resolution strategies
  CONFLICT_RESOLUTION_STRATEGIES = %w[
    server_wins
    client_wins
    latest_timestamp
    manual_resolution
  ].freeze

  class SyncError < StandardError; end
  class ConflictResolutionError < SyncError; end
  class InvalidSyncDataError < SyncError; end

  class << self
    # Get incremental changes since last sync
    # @param company [Company] - Company context
    # @param last_sync_at [Time] - Last sync timestamp
    # @param resource_types [Array] - Optional resource type filter
    # @return [Hash] - Delta changes data
    def get_delta_changes(company:, last_sync_at:, resource_types: nil)
      resource_types ||= default_sync_resources
      delta_data = {}

      resource_types.each do |resource_type|
        model_class = get_model_class_for_resource(resource_type)
        next unless model_class

        changes = get_resource_changes(
          company: company,
          model_class: model_class,
          since: last_sync_at
        )

        delta_data[resource_type] = {
          created: changes[:created],
          updated: changes[:updated],
          deleted: changes[:deleted],
          count: changes[:created].size + changes[:updated].size + changes[:deleted].size
        }
      end

      {
        resources: delta_data,
        sync_metadata: {
          last_sync_at: last_sync_at.iso8601,
          current_sync_at: Time.current.iso8601,
          resource_types: resource_types,
          total_changes: delta_data.values.sum { |r| r[:count] }
        }
      }
    end

    # Get complete dataset for full refresh
    # @param company [Company] - Company context
    # @param user [User] - User requesting sync
    # @param resource_types [Array] - Optional resource type filter
    # @param options [Hash] - Additional options
    # @return [Hash] - Complete dataset
    def get_full_dataset(company:, user:, resource_types: nil, options: {})
      resource_types ||= default_sync_resources
      full_data = {}

      resource_types.each do |resource_type|
        model_class = get_model_class_for_resource(resource_type)
        next unless model_class

        scope = build_sync_scope(company, model_class, options)
        records = serialize_records_for_sync(scope, resource_type)

        # Apply record limit if specified
        if options[:limit_records]
          records = records.first(options[:limit_records])
        end

        full_data[resource_type] = records
      end

      # Log full sync request
      log_sync_operation(
        company: company,
        user: user,
        operation: "full_sync",
        resource_types: resource_types,
        record_count: full_data.values.sum(&:size)
      )

      full_data
    end

    # Process bulk transaction uploads from offline clients
    # @param company [Company] - Company context
    # @param user [User] - User uploading transactions
    # @param transactions [Array] - Transaction data array
    # @param options [Hash] - Additional options
    # @return [Hash] - Processing result
    def process_bulk_transactions(company:, user:, transactions:, options: {})
      processing_start = Time.current
      results = {
        total_transactions: transactions.size,
        successful_syncs: 0,
        failed_syncs: 0,
        conflicts: 0,
        errors: []
      }

      ActiveRecord::Base.transaction do
        transactions.each_with_index do |transaction_data, index|
          begin
            result = process_single_offline_transaction(
              company: company,
              user: user,
              transaction_data: transaction_data,
              sync_options: options
            )

            if result[:success]
              results[:successful_syncs] += 1
            elsif result[:conflict]
              results[:conflicts] += 1
              store_sync_conflict(company, user, transaction_data, result[:conflict_data])
            else
              results[:failed_syncs] += 1
              results[:errors] << {
                index: index,
                error: result[:error],
                transaction_id: transaction_data[:id]
              }
            end
          rescue => e
            results[:failed_syncs] += 1
            results[:errors] << {
              index: index,
              error: e.message,
              transaction_id: transaction_data[:id]
            }
            Rails.logger.error "Bulk transaction sync error: #{e.message}"
          end
        end

        # Rollback on too many failures
        failure_rate = results[:failed_syncs].to_f / results[:total_transactions]
        if failure_rate > 0.5 # More than 50% failed
          raise SyncError, "Too many transaction sync failures (#{failure_rate.round(2)}%)"
        end
      end

      processing_time = Time.current - processing_start
      results[:processing_time] = processing_time.round(2)

      { success: true, data: results }
    rescue SyncError => e
      { success: false, error: e.message, data: results }
    rescue => e
      Rails.logger.error "Bulk transaction processing failed: #{e.message}"
      { success: false, error: "Bulk processing failed", data: results }
    end

    # Validate bulk transactions before processing
    # @param company [Company] - Company context
    # @param transactions [Array] - Transaction data to validate
    # @return [Hash] - Validation result
    def validate_bulk_transactions(company:, transactions:)
      validation_errors = []
      valid_count = 0

      transactions.each_with_index do |transaction_data, index|
        errors = validate_transaction_data(company, transaction_data)

        if errors.empty?
          valid_count += 1
        else
          validation_errors << {
            index: index,
            transaction_id: transaction_data[:id],
            errors: errors
          }
        end
      end

      {
        valid: validation_errors.empty?,
        valid_count: valid_count,
        invalid_count: transactions.size - valid_count,
        errors: validation_errors
      }
    end

    # Get sync status for company/user
    # @param company [Company] - Company context
    # @param user [User] - User context
    # @return [Hash] - Sync status information
    def get_sync_status(company:, user:)
      {
        last_sync_at: get_last_sync_timestamp(company, user),
        pending_uploads: count_pending_uploads(company, user),
        pending_conflicts: count_pending_conflicts(company, user),
        sync_health: assess_sync_health(company, user),
        available_resources: default_sync_resources,
        server_timestamp: Time.current.iso8601
      }
    end

    # Resolve data conflicts
    # @param company [Company] - Company context
    # @param user [User] - User resolving conflicts
    # @param resolutions [Array] - Array of conflict resolutions
    # @return [Hash] - Resolution result
    def resolve_conflicts(company:, user:, resolutions:)
      resolved_count = 0
      failed_resolutions = []

      ActiveRecord::Base.transaction do
        resolutions.each do |resolution|
          begin
            resolve_single_conflict(company, user, resolution)
            resolved_count += 1
          rescue ConflictResolutionError => e
            failed_resolutions << {
              conflict_id: resolution[:conflict_id],
              error: e.message
            }
          end
        end
      end

      if failed_resolutions.empty?
        { success: true, data: { resolved_count: resolved_count } }
      else
        {
          success: false,
          error: "Some conflicts could not be resolved",
          data: {
            resolved_count: resolved_count,
            failed_resolutions: failed_resolutions
          }
        }
      end
    end

    # Get pending conflicts for resolution
    # @param company [Company] - Company context
    # @param user [User] - User context
    # @return [Array] - Array of pending conflicts
    def get_pending_conflicts(company:, user:)
      # This would query a conflicts table if implemented
      # For now, return empty array as placeholder
      []
    end

    private

    def default_sync_resources
      %w[categories items inventories sales_orders payment_methods taxes users]
    end

    def get_model_class_for_resource(resource_type)
      case resource_type.to_s
      when "categories" then Category
      when "items" then Item
      when "inventories" then Inventory
      when "sales_orders" then SalesOrder
      when "payment_methods" then PaymentMethod
      when "taxes" then Tax
      when "users" then User
      else nil
      end
    end

    def get_resource_changes(company:, model_class:, since:)
      base_scope = model_class.where(company: company)

      created = base_scope.where("created_at > ?", since)
                          .where("created_at = updated_at")

      updated = base_scope.where("updated_at > ?", since)
                          .where("created_at < updated_at")

      # For soft deleted records
      deleted = if model_class.respond_to?(:with_deleted)
                  base_scope.only_deleted
                            .where("deleted_at > ?", since)
      else
                  []
      end

      {
        created: serialize_records_for_sync(created, model_class.name.underscore.pluralize),
        updated: serialize_records_for_sync(updated, model_class.name.underscore.pluralize),
        deleted: serialize_records_for_sync(deleted, model_class.name.underscore.pluralize)
      }
    end

    def build_sync_scope(company, model_class, options)
      scope = model_class.where(company: company)

      # Include deleted records if requested
      if options[:include_deleted] && scope.respond_to?(:with_deleted)
        scope = scope.with_deleted
      else
        scope = scope.where(deleted_at: nil) if model_class.column_names.include?("deleted_at")
      end

      scope.order(:updated_at)
    end

    def serialize_records_for_sync(records, resource_type)
      records.map do |record|
        attributes = record.attributes

        # Add sync metadata
        attributes.merge({
          sync_id: generate_sync_id(record),
          last_modified: record.updated_at.iso8601,
          resource_type: resource_type
        })
      end
    end

    def process_single_offline_transaction(company:, user:, transaction_data:, sync_options:)
      # Validate transaction structure
      validation_errors = validate_transaction_data(company, transaction_data)
      return { success: false, error: validation_errors.join(", ") } unless validation_errors.empty?

      # Check for existing transaction
      existing_order = company.sales_orders.find_by(
        order_no: transaction_data[:order_no]
      )

      if existing_order
        return handle_transaction_conflict(existing_order, transaction_data, sync_options)
      end

      # Create new transaction
      result = TransactionService.create_transaction(
        company: company,
        user: user,
        items: transaction_data[:items],
        payment_method_id: find_payment_method_id(company, transaction_data[:payment_method]),
        paid_amount: transaction_data[:paid_amount],
        options: {
          notes: transaction_data[:notes],
          discount_amount: transaction_data[:discount_amount],
          offline_created_at: transaction_data[:created_at]
        }
      )

      if result[:success]
        # Update with offline timestamps if provided
        update_offline_timestamps(result[:sales_order], transaction_data)
        { success: true, sales_order: result[:sales_order] }
      else
        { success: false, error: result[:error] }
      end
    end

    def validate_transaction_data(company, transaction_data)
      errors = []

      errors << "Missing order number" unless transaction_data[:order_no].present?
      errors << "Missing items" unless transaction_data[:items].present?
      errors << "Missing payment amount" unless transaction_data[:paid_amount].present?
      errors << "Missing payment method" unless transaction_data[:payment_method].present?

      # Validate items exist
      if transaction_data[:items].present?
        transaction_data[:items].each do |item_data|
          item = company.items.find_by(id: item_data[:item_id])
          errors << "Item not found: #{item_data[:item_id]}" unless item
        end
      end

      # Validate payment method exists
      if transaction_data[:payment_method].present?
        payment_method = find_payment_method(company, transaction_data[:payment_method])
        errors << "Payment method not found: #{transaction_data[:payment_method]}" unless payment_method
      end

      errors
    end

    def handle_transaction_conflict(existing_order, transaction_data, sync_options)
      conflict_strategy = sync_options[:conflict_strategy] || "server_wins"

      case conflict_strategy
      when "server_wins"
        { success: true, sales_order: existing_order, note: "Server version preserved" }
      when "client_wins"
        # Update existing order with client data (if allowed)
        { success: false, error: "Client wins strategy not implemented for completed orders" }
      when "latest_timestamp"
        client_timestamp = Time.zone.parse(transaction_data[:updated_at]) rescue nil
        if client_timestamp && client_timestamp > existing_order.updated_at
          { success: false, error: "Latest timestamp strategy not implemented" }
        else
          { success: true, sales_order: existing_order, note: "Server version is newer" }
        end
      else
        {
          success: false,
          conflict: true,
          conflict_data: {
            existing_order: existing_order.attributes,
            client_data: transaction_data,
            conflict_type: "duplicate_order_number"
          }
        }
      end
    end

    def find_payment_method_id(company, payment_method_identifier)
      payment_method = find_payment_method(company, payment_method_identifier)
      payment_method&.id
    end

    def find_payment_method(company, identifier)
      # Try to find by ID first, then by name
      if identifier.is_a?(Integer) || identifier.to_s.match?(/^\d+$/)
        company.payment_methods.find_by(id: identifier)
      else
        company.payment_methods.find_by(name: identifier)
      end
    end

    def update_offline_timestamps(sales_order, transaction_data)
      if transaction_data[:created_at].present?
        created_at = Time.zone.parse(transaction_data[:created_at]) rescue nil
        if created_at
          sales_order.update_column(:created_at, created_at)
        end
      end
    end

    def store_sync_conflict(company, user, transaction_data, conflict_data)
      # This would store conflicts in a dedicated table
      Rails.logger.warn "Sync conflict detected for company #{company.id}: #{conflict_data}"
    end

    def generate_sync_id(record)
      "#{record.class.name.downcase}_#{record.id}_#{record.updated_at.to_i}"
    end

    def get_last_sync_timestamp(company, user)
      # This would come from a sync log table
      cache_key = "last_sync:#{company.id}:#{user.id}"
      Rails.cache.read(cache_key)
    end

    def count_pending_uploads(company, user)
      # Placeholder - would count pending offline transactions
      0
    end

    def count_pending_conflicts(company, user)
      # Placeholder - would count unresolved conflicts
      0
    end

    def assess_sync_health(company, user)
      last_sync = get_last_sync_timestamp(company, user)

      if last_sync.nil?
        "never_synced"
      elsif last_sync < 1.day.ago
        "outdated"
      elsif last_sync < 1.hour.ago
        "stale"
      else
        "healthy"
      end
    end

    def resolve_single_conflict(company, user, resolution)
      # Placeholder for conflict resolution logic
      raise ConflictResolutionError, "Conflict resolution not implemented"
    end

    def log_sync_operation(company:, user:, operation:, resource_types:, record_count:)
      UserAction.log_action(
        user: user,
        action_type: :sync,
        resource_type: "SyncOperation",
        resource_id: company.id,
        details: {
          operation: operation,
          resource_types: resource_types,
          record_count: record_count,
          timestamp: Time.current.iso8601
        }
      )
    end
  end
end
