FactoryBot.define do
  factory :sales_order do
    sequence(:order_no) { |n| "SO-#{n.to_s.rjust(6, '0')}" }
    sub_total { 100.00 }
    tax_amount { 10.00 }
    grand_total { 110.00 }
    paid_amount { 110.00 }
    status { :pending }
    company
    payment_method
  end
end
