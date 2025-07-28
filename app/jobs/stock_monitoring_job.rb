class StockMonitoringJob < ApplicationJob
  queue_as :default

  def perform(company_id = nil)
    if company_id
      # Monitor a specific company
      monitor_company_stock(company_id)
    else
      # Monitor all active companies
      Company.active.not_deleted.find_each do |company|
        monitor_company_stock(company.id)
      end
    end
  end

  private

  def monitor_company_stock(company_id)
    company = Company.find(company_id)

    Rails.logger.info "Starting stock monitoring for company: #{company.name} (#{company_id})"

    alerts_triggered = StockAlert.check_and_trigger_all(company_id)

    Rails.logger.info "Stock monitoring completed for company: #{company.name}. Alerts triggered: #{alerts_triggered}"

    # Log the monitoring activity
    UserAction.create!(
      company_id: company_id,
      user_id: nil, # System action
      user_session_id: nil,
      action: "stock_monitoring_completed",
      resource_type: "Company",
      resource_id: company_id.to_s,
      details: {
        company_name: company.name,
        alerts_triggered: alerts_triggered,
        monitored_at: Time.current
      },
      ip_address: "127.0.0.1", # System IP
      success: true
    )

  rescue => e
    Rails.logger.error "Stock monitoring failed for company #{company_id}: #{e.message}"

    # Log the failure
    UserAction.create!(
      company_id: company_id,
      user_id: nil,
      user_session_id: nil,
      action: "stock_monitoring_failed",
      resource_type: "Company",
      resource_id: company_id.to_s,
      details: {
        error_message: e.message,
        error_class: e.class.name,
        failed_at: Time.current
      },
      ip_address: "127.0.0.1",
      success: false
    )

    raise e
  end
end
