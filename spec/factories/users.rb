FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    password { "password123" }
    password_confirmation { "password123" }
    role { :cashier }
    company
    active { true }

    trait :cashier do
      role { :cashier }
    end

    trait :manager do
      role { :manager }
    end

    trait :owner do
      role { :owner }
    end

    trait :inactive do
      active { false }
    end
  end
end
