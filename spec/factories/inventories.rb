FactoryBot.define do
  factory :inventory do
    stock { 100 }
    minimum_stock { 10 }
    reserved_stock { 0 }
    company
    item
  end
end
