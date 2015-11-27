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
    sequence(:title) { |n| "Product #{n}" }

    price 1000
    tax_exempt false
  end

  factory :product_with_float_price do # This only exists in the dummy/ app
    sequence(:title) { |n| "Product #{n}" }

    price 10.00
    tax_exempt false
  end

  factory :user do # This only exists in the dummy/ app
    sequence(:email) { |n| "user_#{n}@effective_orders.test"}

    password '12345678'

    after(:build) { |user| user.skip_confirmation! if user.respond_to?(:skip_confirmation!) }
  end

  factory :customer, :class => Effective::Customer do
    association :user
  end

  factory :subscription, :class => Effective::Subscription do
    association :customer

    before(:create) do |subscription|
      stripe_plan = Stripe::Plan.create(:id => "stripe_plan_#{subscription.object_id}", :name => 'Stripe Plan', :amount => 1000, :currency => 'USD', :interval => 'month')
      stripe_coupon = FactoryGirl.create(:stripe_coupon)

      subscription.stripe_plan_id = stripe_plan.id
      subscription.stripe_coupon_id = stripe_coupon.id
    end
  end

  factory :cart, :class => Effective::Cart do
    association :user

    before(:create) do |cart|
      3.times { cart.cart_items << FactoryGirl.create(:cart_item, :cart => cart) }
    end
  end

  factory :cart_item, :class => Effective::CartItem do
    association :purchasable, :factory => :product
    association :cart, :factory => :cart

    quantity 1
  end

  factory :cart_with_subscription, :class => Effective::Cart do
    association :user

    before(:create) do |cart|
      cart.cart_items << FactoryGirl.create(:cart_item, :cart => cart)
      cart.cart_items << FactoryGirl.create(:cart_item, :cart => cart, :purchasable => FactoryGirl.create(:subscription))
    end
  end

  factory :order, :class => Effective::Order do
    association :user

    before(:create) do |order|
      order.billing_address = FactoryGirl.build(:address, :addressable => order)
      order.shipping_address = FactoryGirl.build(:address, :addressable => order)

      3.times { order.order_items << FactoryGirl.create(:order_item, :order => order) }
    end
  end

  factory :order_with_subscription, :class => Effective::Order do
    association :user

    before(:create) do |order|
      order.billing_address = FactoryGirl.build(:address, :addressable => order)
      order.shipping_address = FactoryGirl.build(:address, :addressable => order)

      order.order_items << FactoryGirl.create(:order_item, :order => order)
      order.order_items << FactoryGirl.create(:order_item, :purchasable => FactoryGirl.create(:subscription), :order => order)
    end
  end

  factory :order_item, :class => Effective::OrderItem do
    association :purchasable, :factory => :product
    association :order, :factory => :order

    sequence(:title) { |n| "Order Item #{n}" }
    quantity 1
    price 1000
    tax_exempt false
    tax_rate 0.05
  end

  factory :purchased_order, :parent => :order do
    after(:create) { |order| order.purchase!('by a test') }
  end

  factory :declined_order, :parent => :order do
    after(:create) { |order| order.decline! }
  end

  factory :stripe_coupon, :class => Stripe::Coupon do
    to_create {|c| c.save}
    duration 'once'
  end
end
