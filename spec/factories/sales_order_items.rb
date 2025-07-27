FactoryBot.define do
  factory :sales_order_item do
    price { 25.00 }
    quantity { 2 }
    tax_amount { 5.00 }
    sales_order
    item
  end
end
