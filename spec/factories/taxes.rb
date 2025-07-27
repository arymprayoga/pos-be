FactoryBot.define do
  factory :tax do
    name { "Tax #{rand(1..100)}" }
    rate { 0.1 }
    company
    active { true }
    is_default { false }
  end
end
