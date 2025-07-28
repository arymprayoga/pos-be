class Item < ApplicationRecord
  acts_as_tenant
  belongs_to :company
  belongs_to :category
  has_one :inventory, dependent: :destroy
  has_many :sales_order_items, dependent: :destroy
  has_many :inventory_ledgers, dependent: :destroy
  has_many :price_histories, dependent: :destroy
  has_one :stock_alert, dependent: :destroy

  validates :sku, presence: true, uniqueness: { scope: :company_id, conditions: -> { where(deleted_at: nil) } }
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validate :validate_variants_structure

  before_update :track_price_change, if: :price_changed?

  scope :active, -> { where(active: true) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :ordered, -> { order(:sort_order, :name) }
  scope :with_variants, -> { where.not(variants: {}) }

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

  # Variant management methods
  def has_variants?
    variants.present? && variants.any?
  end

  def variant_types
    variants.keys
  end

  def variant_options(type)
    variants[type.to_s] || []
  end

  def add_variant_type(type, options = [])
    self.variants = variants.merge(type.to_s => Array(options))
    save!
  end

  def remove_variant_type(type)
    new_variants = variants.dup
    new_variants.delete(type.to_s)
    update!(variants: new_variants)
  end

  def add_variant_option(type, option)
    current_options = variant_options(type)
    return false if current_options.include?(option.to_s)

    new_options = current_options + [ option.to_s ]
    add_variant_type(type, new_options)
  end

  def remove_variant_option(type, option)
    current_options = variant_options(type)
    new_options = current_options - [ option.to_s ]

    if new_options.empty?
      remove_variant_type(type)
    else
      add_variant_type(type, new_options)
    end
  end

  def variant_combinations
    return [] unless has_variants?

    combinations = variants.values.first.product(*variants.values[1..-1])
    combinations.map do |combination|
      Array(combination).each_with_index.map { |value, index| [ variant_types[index], value ] }.to_h
    end
  end

  # Price management methods
  def update_price!(new_price, reason: nil, effective_date: Time.current)
    old_price = price

    transaction do
      update!(price: new_price)
      PriceHistory.create_for_price_change(
        self,
        old_price,
        new_price,
        reason: reason,
        effective_date: effective_date
      )
    end
  end

  def price_history_summary
    price_histories.recent.limit(10)
  end

  def latest_price_change
    price_histories.recent.first
  end

  def price_trend(days: 30)
    changes = price_histories.where(effective_date: days.days.ago..Time.current)

    return "stable" if changes.empty?

    increases = changes.select(&:price_increased?).count
    decreases = changes.select(&:price_decreased?).count

    if increases > decreases
      "increasing"
    elsif decreases > increases
      "decreasing"
    else
      "fluctuating"
    end
  end

  private

  def validate_variants_structure
    return unless variants.present?

    unless variants.is_a?(Hash)
      errors.add(:variants, "must be a hash")
      return
    end

    variants.each do |type, options|
      unless type.is_a?(String) && type.present?
        errors.add(:variants, "variant type must be a non-empty string")
      end

      unless options.is_a?(Array)
        errors.add(:variants, "variant options must be an array")
        next
      end

      options.each do |option|
        unless option.is_a?(String) && option.present?
          errors.add(:variants, "each variant option must be a non-empty string")
        end
      end
    end
  end

  def track_price_change
    return unless price_was.present?

    @price_change_data = {
      old_price: price_was,
      new_price: price,
      reason: "Price updated via API"
    }
  end
end
