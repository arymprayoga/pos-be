class Inventory < ApplicationRecord
  acts_as_tenant
  belongs_to :company
  belongs_to :item
  has_many :inventory_ledgers, through: :item

  validates :stock, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :minimum_stock, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reserved_stock, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :low_stock, -> { where("stock <= minimum_stock") }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def available_stock
    stock - reserved_stock
  end

  def low_stock?
    stock <= minimum_stock
  end
end
