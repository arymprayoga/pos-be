FactoryBot.define do
  factory :inventory_ledger do
    movement_type { :stock_in }
    quantity { 10 }
    remarks { "Initial stock" }
    company
    item
  end
end
