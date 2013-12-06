require 'factory_girl'

FactoryGirl.define do
  factory :address, :class => Effective::Address do
    category 'billing'
    full_name 'Peter Pan'
    sequence(:address1) { |n| "1234#{n} Fake Street" }
    city 'San Antonio'
    state_code 'TX'
    country_code 'US'
    postal_code '92387'
  end

  factory :product do # This only exists in the dummy/ app
    sequence(:title) { |n| "Product #{n}"}

    price 10.00
    tax_exempt false
    quickbooks_item_name "Quickbooks Item Name"
  end

  factory :cart, :class => Effective::Cart do
    user_id 1

    before(:create) do |cart|
      3.times { cart.cart_items << FactoryGirl.create(:cart_item, :cart => cart) }
    end
  end

  factory :cart_item, :class => Effective::CartItem do
    association :purchasable, :factory => :product
    association :cart, :factory => :cart

    quantity 1
  end

  factory :order, :class => Effective::Order do
    user_id 1

    before(:create) do |order|
      order.billing_address = FactoryGirl.build(:address, :addressable => order)

      3.times { order.order_items << FactoryGirl.create(:order_item, :order => order) }
    end
  end

  factory :order_item, :class => Effective::OrderItem do
    association :purchasable, :factory => :product
    association :order, :factory => :order

    sequence(:title) { |n| "Order Item #{n}" }
    sequence(:quickbooks_item_name) { |n| "Order Item #{n} QB Item Name" }
    quantity 1
    price 10.00
    tax_exempt false
    tax_rate 0.05
  end

  factory :purchased_order, :parent => :order do
    after(:create) { |order| order.purchase! }
  end

  factory :declined_order, :parent => :order do
    after(:create) { |order| order.decline! }
  end

end
