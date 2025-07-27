FactoryBot.define do
  factory :permission do
    company
    sequence(:name) { |n| "permission_#{n}" }
    resource { 'transactions' }
    action { 'read' }
    description { 'A test permission' }
    system_permission { false }

    trait :system do
      system_permission { true }
    end

    trait :inventory do
      resource { 'inventory' }
      action { 'manage_stock' }
      name { 'inventory.manage_stock' }
    end

    trait :reports do
      resource { 'reports' }
      action { 'read' }
      name { 'reports.read' }
    end

    trait :void_transaction do
      resource { 'transactions' }
      action { 'void' }
      name { 'transactions.void' }
    end
  end
end
