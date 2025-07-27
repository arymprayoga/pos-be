FactoryBot.define do
  factory :payment_method do
    name { [ "Cash", "Credit Card", "Debit Card", "Bank Transfer" ].sample }
    company
    active { true }
    is_default { false }
    sort_order { 1 }
  end
end
