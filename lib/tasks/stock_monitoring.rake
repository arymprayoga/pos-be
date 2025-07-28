namespace :stock do
  desc "Monitor stock levels and trigger alerts for all companies"
  task monitor_all: :environment do
    puts "Starting stock monitoring for all companies..."

    start_time = Time.current
    StockMonitoringJob.perform_now
    duration = Time.current - start_time

    puts "Stock monitoring completed in #{duration.round(2)} seconds"
  end

  desc "Monitor stock levels for a specific company"
  task :monitor_company, [ :company_id ] => :environment do |t, args|
    company_id = args[:company_id]

    if company_id.blank?
      puts "Error: Please provide a company_id"
      puts "Usage: rails stock:monitor_company[company_id]"
      exit 1
    end

    company = Company.find(company_id)
    puts "Starting stock monitoring for company: #{company.name} (#{company_id})"

    start_time = Time.current
    StockMonitoringJob.perform_now(company_id)
    duration = Time.current - start_time

    puts "Stock monitoring completed for #{company.name} in #{duration.round(2)} seconds"
  rescue ActiveRecord::RecordNotFound
    puts "Error: Company with ID #{company_id} not found"
    exit 1
  end

  desc "Setup default stock alerts for all items"
  task setup_default_alerts: :environment do
    puts "Setting up default stock alerts for all items..."

    alerts_created = 0

    Item.active.not_deleted.includes(:stock_alert, :inventory).find_each do |item|
      next if item.stock_alert.present?

      StockAlert.setup_default_alerts_for_item(item)
      alerts_created += 1

      print "." if alerts_created % 50 == 0
    end

    puts "\nCreated #{alerts_created} default stock alerts"
  end

  desc "Clean up old stock alert logs"
  task :cleanup_logs, [ :days ] => :environment do |t, args|
    days = args[:days]&.to_i || 30

    puts "Cleaning up stock alert logs older than #{days} days..."

    deleted_count = UserAction.where(action: [ "stock_alert_triggered", "stock_monitoring_completed", "stock_monitoring_failed" ])
                             .where("created_at < ?", days.days.ago)
                             .delete_all

    puts "Deleted #{deleted_count} old stock alert log entries"
  end

  desc "Show stock alert statistics"
  task stats: :environment do
    puts "Stock Alert Statistics"
    puts "=" * 50

    Company.active.not_deleted.each do |company|
      puts "\nCompany: #{company.name}"
      puts "-" * 30

      total_items = company.items.active.not_deleted.count
      items_with_alerts = company.stock_alerts.count
      enabled_alerts = company.stock_alerts.enabled.count

      low_stock_items = company.items.joins(:inventory, :stock_alert)
                              .where("inventories.stock <= stock_alerts.threshold_value")
                              .where(stock_alerts: { alert_type: "low_stock", enabled: true })
                              .count

      out_of_stock_items = company.items.joins(:inventory)
                                 .where("inventories.stock = 0")
                                 .count

      puts "Total items: #{total_items}"
      puts "Items with alerts: #{items_with_alerts}"
      puts "Enabled alerts: #{enabled_alerts}"
      puts "Low stock items: #{low_stock_items}"
      puts "Out of stock items: #{out_of_stock_items}"

      recent_alerts = UserAction.where(company_id: company.id)
                               .where(action: "stock_alert_triggered")
                               .where("created_at > ?", 24.hours.ago)
                               .count

      puts "Alerts triggered (last 24h): #{recent_alerts}"
    end
  end
end
