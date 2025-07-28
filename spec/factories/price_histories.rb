FactoryBot.define do
  factory :price_history do
    company { nil }
    item { nil }
    old_price { "9.99" }
    new_price { "9.99" }
    effective_date { "2025-07-28 05:38:07" }
    reason { "MyText" }
    created_by { "" }
    updated_by { "" }
  end
end
