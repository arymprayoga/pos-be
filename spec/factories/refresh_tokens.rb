FactoryBot.define do
  factory :refresh_token do
    association :user
    association :company
    token_hash { Digest::SHA256.hexdigest(SecureRandom.hex(32)) }
    device_fingerprint { Faker::Internet.user_agent }
    expires_at { 30.days.from_now }
    revoked_at { nil }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :revoked do
      revoked_at { 1.hour.ago }
    end

    trait :expired_and_revoked do
      expires_at { 1.day.ago }
      revoked_at { 1.hour.ago }
    end
  end
end
