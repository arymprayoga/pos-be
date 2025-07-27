FactoryBot.define do
  factory :category do
    name { Faker::Commerce.department }
    company
    active { true }
    sort_order { 1 }
  end
end
