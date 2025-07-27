class SalesOrder < ApplicationRecord
  acts_as_tenant
  belongs_to :company
  belongs_to :payment_method
  has_many :sales_order_items, dependent: :destroy
  has_many :items, through: :sales_order_items

  enum :status, { pending: 0, completed: 1, voided: 2 }

  validates :order_no, presence: true, uniqueness: { scope: :company_id, conditions: -> { where(deleted_at: nil) } }
  validates :sub_total, presence: true, numericality: { greater_than: 0 }
  validates :grand_total, presence: true, numericality: { greater_than: 0 }
  validates :paid_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

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
      update!(status: :voided)
      sales_order_items.each(&:revert_inventory!)
    end
  end
end
