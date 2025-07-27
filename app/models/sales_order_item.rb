class SalesOrderItem < ApplicationRecord
  belongs_to :sales_order
  belongs_to :item
  has_many :inventory_ledgers, dependent: :destroy

  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :quantity, presence: true, numericality: { greater_than: 0 }

  scope :not_deleted, -> { where(deleted_at: nil) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def line_total
    price * quantity
  end

  def line_total_with_tax
    line_total + tax_amount
  end

  def company
    sales_order.company
  end

  def revert_inventory!
    return unless item.track_inventory?

    InventoryLedger.create!(
      company: company,
      item: item,
      movement_type: :stock_in,
      quantity: quantity,
      sales_order_item: self,
      remarks: "Reverted from voided order #{sales_order.order_no}"
    )

    item.inventory.increment!(:stock, quantity)
  end
end
