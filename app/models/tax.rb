class Tax < ApplicationRecord
  acts_as_tenant
  belongs_to :company
  has_many :sales_orders, dependent: :restrict_with_error
  has_many :sales_order_items, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :company_id, conditions: -> { where(deleted_at: nil) } }
  validates :rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than: 1 }

  scope :active, -> { where(active: true) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :default, -> { where(is_default: true) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def rate_percentage
    (rate * 100).round(2)
  end
end
