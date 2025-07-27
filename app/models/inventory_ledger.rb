class InventoryLedger < ApplicationRecord
  acts_as_tenant
  belongs_to :company
  belongs_to :item
  belongs_to :sales_order_item, optional: true

  enum :movement_type, { stock_in: 0, stock_out: 1, adjustment: 2 }

  validates :movement_type, presence: true
  validates :quantity, presence: true, numericality: { other_than: 0 }

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def quantity_with_sign
    case movement_type
    when "stock_in", "adjustment"
      quantity.abs
    when "stock_out"
      -quantity.abs
    end
  end
end
