class TokenCleanupJob < ApplicationJob
  queue_as :default

  # Clean up expired and old revoked refresh tokens
  def perform
    Rails.logger.info "Starting token cleanup job..."

    begin
      # Count tokens before cleanup
      expired_count = RefreshToken.expired.count
      old_revoked_count = RefreshToken.where("revoked_at < ?", 30.days.ago).count

      # Perform cleanup
      deleted_count = RefreshToken.cleanup_expired!

      Rails.logger.info "Token cleanup completed. Removed #{deleted_count} tokens (#{expired_count} expired, #{old_revoked_count} old revoked)"

      # Report metrics if monitoring is available
      if defined?(Rails::Performance)
        Rails::Performance.increment("tokens.cleanup.deleted", deleted_count)
        Rails::Performance.increment("tokens.cleanup.runs")
      end

    rescue => e
      Rails.logger.error "Token cleanup job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Report error if monitoring is available
      if defined?(Rails::Performance)
        Rails::Performance.increment("tokens.cleanup.errors")
      end

      raise e
    end
  end
end
