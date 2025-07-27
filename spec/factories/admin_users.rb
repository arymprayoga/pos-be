FactoryBot.define do
  factory :admin_user do
    email { Faker::Internet.email }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
