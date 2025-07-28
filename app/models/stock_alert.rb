class StockAlert < ApplicationRecord
  include Auditable

  acts_as_tenant
  belongs_to :company
  belongs_to :item

  enum :alert_type, {
    low_stock: 0,
    out_of_stock: 1,
    overstock: 2
  }

  validates :alert_type, presence: true
  validates :threshold_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :item_id, uniqueness: { scope: :company_id }

  scope :enabled, -> { where(enabled: true) }
  scope :due_for_check, -> { where("last_alerted_at IS NULL OR last_alerted_at < ?", 1.hour.ago) }

  def should_trigger_alert?
    return false unless enabled?
    return false if recently_alerted?

    case alert_type
    when "low_stock"
      item.current_stock <= threshold_value && item.current_stock > 0
    when "out_of_stock"
      item.current_stock == 0
    when "overstock"
      item.current_stock >= threshold_value
    else
      false
    end
  end

  def trigger_alert!
    return false unless should_trigger_alert?

    update!(last_alerted_at: Time.current)

    # Send email notifications
    send_email_notifications

    # Log the alert
    log_alert_triggered

    true
  end

  def recently_alerted?(within: 1.hour)
    last_alerted_at.present? && last_alerted_at > within.ago
  end

  def alert_message
    case alert_type
    when "low_stock"
      "Low stock alert: #{item.name} (#{item.sku}) has #{item.current_stock} units remaining (threshold: #{threshold_value})"
    when "out_of_stock"
      "Out of stock alert: #{item.name} (#{item.sku}) is out of stock"
    when "overstock"
      "Overstock alert: #{item.name} (#{item.sku}) has #{item.current_stock} units (threshold: #{threshold_value})"
    end
  end

  def self.check_and_trigger_all(company_id)
    alerts_triggered = 0

    enabled.where(company_id: company_id).due_for_check.includes(:item).find_each do |alert|
      alerts_triggered += 1 if alert.trigger_alert!
    end

    alerts_triggered
  end

  def self.setup_default_alerts_for_item(item)
    return if exists?(company_id: item.company_id, item_id: item.id)

    create!(
      company: item.company,
      item: item,
      alert_type: :low_stock,
      threshold_value: item.inventory&.minimum_stock || 5,
      enabled: true
    )
  end

  private

  def send_email_notifications
    # Get notification recipients (company managers and owners)
    recipients = company.users.active.not_deleted
                       .where(role: [ "manager", "owner" ])
                       .pluck(:email)

    return if recipients.empty?

    # Send appropriate email based on alert type
    case alert_type
    when "low_stock"
      StockAlertMailer.low_stock_alert(self, recipients).deliver_now
    when "out_of_stock"
      StockAlertMailer.out_of_stock_alert(self, recipients).deliver_now
    when "overstock"
      StockAlertMailer.overstock_alert(self, recipients).deliver_now
    end
  rescue => e
    Rails.logger.error "Failed to send stock alert email: #{e.message}"
  end

  def log_alert_triggered
    UserAction.log_action(
      user_id: nil, # System action
      user_session_id: nil,
      action: "stock_alert_triggered",
      resource_type: "StockAlert",
      resource_id: id,
      details: {
        alert_type: alert_type,
        item_name: item.name,
        item_sku: item.sku,
        current_stock: item.current_stock,
        threshold_value: threshold_value,
        message: alert_message
      },
      success: true
    )
  end
end
