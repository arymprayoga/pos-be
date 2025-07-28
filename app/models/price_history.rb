class PriceHistory < ApplicationRecord
  include Auditable

  acts_as_tenant
  belongs_to :company
  belongs_to :item

  validates :old_price, presence: true, numericality: { greater_than: 0 }
  validates :new_price, presence: true, numericality: { greater_than: 0 }
  validates :effective_date, presence: true

  scope :ordered, -> { order(:effective_date) }
  scope :recent, -> { order(effective_date: :desc) }
  scope :for_item, ->(item_id) { where(item_id: item_id) }

  def price_change_amount
    new_price - old_price
  end

  def price_change_percentage
    return 0 if old_price.zero?

    ((new_price - old_price) / old_price) * 100
  end

  def price_increased?
    new_price > old_price
  end

  def price_decreased?
    new_price < old_price
  end

  def effective?
    effective_date <= Time.current
  end

  def self.create_for_price_change(item, old_price, new_price, reason: nil, effective_date: Time.current)
    create!(
      company: item.company,
      item: item,
      old_price: old_price,
      new_price: new_price,
      effective_date: effective_date,
      reason: reason
    )
  end

  def self.latest_for_item(item_id)
    for_item(item_id).recent.first
  end

  def self.price_changes_summary(company_id, from_date: 30.days.ago, to_date: Time.current)
    where(company_id: company_id)
      .where(effective_date: from_date..to_date)
      .group(:item_id)
      .includes(:item)
      .order(:effective_date)
  end
end
