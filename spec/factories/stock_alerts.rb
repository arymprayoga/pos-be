FactoryBot.define do
  factory :stock_alert do
    company { nil }
    item { nil }
    alert_type { 1 }
    threshold_value { 1 }
    enabled { false }
    last_alerted_at { "2025-07-28 05:39:35" }
    created_by { "" }
    updated_by { "" }
  end
end
