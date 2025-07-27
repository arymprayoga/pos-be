class User < ApplicationRecord
  acts_as_tenant
  belongs_to :company

  has_secure_password

  enum :role, { cashier: 0, manager: 1, owner: 2 }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { scope: :company_id, conditions: -> { where(deleted_at: nil) } }
  validates :role, presence: true

  scope :active, -> { where(active: true) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def can_manage_inventory?
    manager? || owner?
  end

  def can_access_reports?
    manager? || owner?
  end

  def can_void_transactions?
    manager? || owner?
  end

  def can_override_prices?
    manager? || owner?
  end
end
