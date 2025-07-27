FactoryBot.define do
  factory :item do
    sequence(:sku) { |n| "SKU-#{n.to_s.rjust(6, '0')}" }
    name { Faker::Commerce.product_name }
    price { Faker::Commerce.price(range: 1.00..100.00) }
    company
    category
    active { true }
    track_inventory { true }
    sort_order { 1 }
  end
end
