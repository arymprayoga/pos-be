FactoryBot.define do
  factory :company do
    name { Faker::Company.name }
    email { Faker::Internet.email }
    currency { "USD" }
    timezone { "UTC" }
    active { true }
  end
end
