class Item < ApplicationRecord
  acts_as_tenant
  belongs_to :company
  belongs_to :category
  has_one :inventory, dependent: :destroy
  has_many :sales_order_items, dependent: :destroy
  has_many :inventory_ledgers, dependent: :destroy

  validates :sku, presence: true, uniqueness: { scope: :company_id, conditions: -> { where(deleted_at: nil) } }
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :ordered, -> { order(:sort_order, :name) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def current_stock
    inventory&.stock || 0
  end

  def low_stock?
    return false unless track_inventory?

    current_stock <= (inventory&.minimum_stock || 0)
  end

  def in_stock?
    return true unless track_inventory?

    current_stock > 0
  end
end
