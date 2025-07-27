FactoryBot.define do
  factory :user_session do
    company
    user
    session_token { SecureRandom.urlsafe_base64(32) }
    device_fingerprint { SecureRandom.hex(8) }
    ip_address { '192.168.1.1' }
    user_agent { 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' }
    last_activity_at { Time.current }
    expired_at { 8.hours.from_now }

    trait :expired do
      expired_at { 1.hour.ago }
      logged_out_at { nil }
    end

    trait :logged_out do
      logged_out_at { 1.hour.ago }
      expired_at { 1.hour.ago }
    end

    trait :active do
      expired_at { 8.hours.from_now }
      logged_out_at { nil }
    end
  end
end
