class PaymentMethod < ApplicationRecord
  acts_as_tenant
  belongs_to :company
  has_many :sales_orders, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :company_id, conditions: -> { where(deleted_at: nil) } }

  scope :active, -> { where(active: true) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :default, -> { where(is_default: true) }
  scope :ordered, -> { order(:sort_order, :name) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end
end
