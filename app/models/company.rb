class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :inventories, dependent: :destroy
  has_many :taxes, dependent: :destroy
  has_many :payment_methods, dependent: :destroy
  has_many :sales_orders, dependent: :destroy
  has_many :inventory_ledgers, dependent: :destroy
  has_many :permissions, dependent: :destroy
  has_many :user_sessions, dependent: :destroy
  has_many :user_actions, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :currency, presence: true
  validates :timezone, presence: true

  scope :active, -> { where(active: true) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end
end
