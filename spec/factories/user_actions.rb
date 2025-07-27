FactoryBot.define do
  factory :user_action do
    company
    user
    user_session
    action { 'login' }
    resource_type { 'Authentication' }
    ip_address { '192.168.1.1' }
    user_agent { 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' }
    success { true }
    details { {} }

    trait :failed do
      success { false }
      details { { error: 'Invalid credentials' } }
    end

    trait :sensitive do
      action { 'void_transaction' }
      resource_type { 'Transaction' }
      resource_id { SecureRandom.uuid }
    end

    trait :login do
      action { 'login_success' }
      resource_type { 'Authentication' }
    end

    trait :logout do
      action { 'logout' }
      resource_type { 'Authentication' }
    end
  end
end
