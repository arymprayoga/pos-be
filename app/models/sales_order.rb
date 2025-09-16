class SalesOrder < ApplicationRecord
  acts_as_tenant
  belongs_to :company
  belongs_to :payment_method
  has_many :sales_order_items, dependent: :destroy
  has_many :items, through: :sales_order_items

  enum :status, { pending: 0, completed: 1, voided: 2, refunded: 3 }

  validates :order_no, presence: true, uniqueness: { scope: :company_id, conditions: -> { where(deleted_at: nil) } }
  validates :sub_total, presence: true, numericality: { greater_than: 0 }
  validates :grand_total, presence: true, numericality: { greater_than: 0 }
  validates :paid_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where(created_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(created_at: 1.week.ago.beginning_of_week..Time.current) }
  scope :this_month, -> { where(created_at: 1.month.ago.beginning_of_month..Time.current) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def total_items
    sales_order_items.sum(:quantity)
  end

  def can_be_voided?
    completed? && created_at > 24.hours.ago
  end

  def void!
    raise "Cannot void this order" unless can_be_voided?

    transaction do
      update!(status: :voided, voided_at: Time.current)
      sales_order_items.each(&:revert_inventory!)
    end
  end

  # Transaction lifecycle methods
  def complete!
    return false unless pending?

    transaction do
      # Process inventory updates for all items
      sales_order_items.each do |item|
        next unless item.item.track_inventory?

        # Update inventory
        inventory = item.item.inventory
        inventory.decrement!(:stock, item.quantity)

        # Create inventory ledger entry
        InventoryLedger.create!(
          company: company,
          item: item.item,
          movement_type: :stock_out,
          quantity: -item.quantity,
          sales_order_item: item,
          remarks: "Sale - Order #{order_no}"
        )
      end

      update!(status: :completed, completed_at: Time.current)
    end

    true
  rescue => e
    Rails.logger.error "Failed to complete order #{order_no}: #{e.message}"
    false
  end

  def refund!(refund_amount: nil, reason: nil)
    return false unless completed?

    refund_amount ||= grand_total

    transaction do
      # Revert inventory for all items
      sales_order_items.each(&:revert_inventory!)

      update!(
        status: :refunded,
        refunded_at: Time.current,
        refund_amount: refund_amount,
        refund_reason: reason
      )
    end

    true
  rescue => e
    Rails.logger.error "Failed to refund order #{order_no}: #{e.message}"
    false
  end

  # Calculate net total (grand_total - change_amount for cash transactions)
  def net_total
    grand_total - (change_amount || 0)
  end

  # Check if payment was exact (no change given)
  def exact_payment?
    change_amount.nil? || change_amount.zero?
  end

  # Get payment summary for receipt
  def payment_summary
    {
      method: payment_method.name,
      sub_total: sub_total,
      tax_amount: tax_amount || 0,
      discount_amount: discount_amount || 0,
      grand_total: grand_total,
      paid_amount: paid_amount,
      change_amount: change_amount || 0,
      net_total: net_total
    }
  end

  # Check if order can be edited
  def editable?
    pending?
  end

  # Check if order can be cancelled
  def cancellable?
    pending? || (completed? && created_at > 1.hour.ago)
  end

  # Get order age in hours
  def age_in_hours
    ((Time.current - created_at) / 1.hour).round(2)
  end

  # Get cashier information
  def cashier
    User.find_by(id: created_by)
  end

  def cashier_name
    cashier&.name || "Unknown"
  end

  # Generate receipt data
  def receipt_data
    PaymentService.generate_payment_receipt(self)
  end

  # Check if order has tax
  def taxed?
    tax_amount.present? && tax_amount > 0
  end

  # Check if order has discount
  def discounted?
    discount_amount.present? && discount_amount > 0
  end

  # Validate order totals
  def validate_totals
    calculated_subtotal = sales_order_items.sum(&:line_total)
    calculated_grand_total = calculated_subtotal + (tax_amount || 0) - (discount_amount || 0)

    {
      valid: (sub_total == calculated_subtotal && grand_total == calculated_grand_total),
      calculated_subtotal: calculated_subtotal,
      calculated_grand_total: calculated_grand_total,
      stored_subtotal: sub_total,
      stored_grand_total: grand_total
    }
  end

  # Get formatted amounts for display
  def formatted_amounts
    {
      sub_total: PaymentService.format_rupiah(sub_total),
      tax_amount: PaymentService.format_rupiah(tax_amount || 0),
      discount_amount: PaymentService.format_rupiah(discount_amount || 0),
      grand_total: PaymentService.format_rupiah(grand_total),
      paid_amount: PaymentService.format_rupiah(paid_amount),
      change_amount: PaymentService.format_rupiah(change_amount || 0)
    }
  end

  # Get order summary for API responses
  def summary
    {
      id: id,
      order_no: order_no,
      status: status,
      total_items: total_items,
      grand_total: grand_total,
      payment_method: payment_method.name,
      created_at: created_at,
      completed_at: completed_at,
      cashier: cashier_name,
      age_hours: age_in_hours
    }
  end
end
