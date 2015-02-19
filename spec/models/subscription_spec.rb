require 'spec_helper'

# # Attributes
describe Effective::Subscription do
  let(:subscription) { FactoryGirl.create(:subscription) }

  before { StripeMock.start }
  after { StripeMock.stop }

  describe '#stripe_plan' do

  end

  describe '#stripe_plan_id=' do
    it 'assigns the stripe_plan_id' do
      subscription.stripe_plan_id = 'Plan 9'
      subscription.stripe_plan_id.should eq 'Plan 9'
    end

    it 'rejects an invalid stripe_plan' do
      subscription.stripe_plan.present?.should eq true  # From the Factory

      subscription.stripe_plan_id = 'Plan 9'  # Set it to an Invalid plan
      subscription.stripe_plan_id.should eq 'Plan 9'

      subscription.stripe_plan.should eq nil
    end

    it 'sets the stripe plan' do
      subscription = Effective::Subscription.new()

      plan = ::Stripe::Plan.create(:id => 'stripe_plan', :name => 'Stripe Plan', :amount => 1000, :currency => 'USD', :interval => 'month')
      subscription.stripe_plan_id = plan.id
      subscription.stripe_plan.id.should eq plan.id
    end
  end

  describe '#stripe_coupon_id=' do
    it 'assigns the stripe_coupon_id' do
      subscription.stripe_coupon_id = 'Plan 9'
      subscription.stripe_coupon_id.should eq 'Plan 9'
    end

    it 'rejects an invalid stripe_coupon' do
      subscription.stripe_coupon.present?.should eq true  # From the Factory

      subscription.stripe_coupon_id = 'Plan 9'  # Set it to an Invalid plan
      subscription.stripe_coupon_id.should eq 'Plan 9'

      subscription.stripe_coupon.should eq nil
    end

    it 'sets the stripe coupon' do
      subscription = Effective::Subscription.new()

      coupon = ::Stripe::Coupon.create()
      subscription.stripe_coupon_id = coupon.id
      subscription.stripe_coupon.id.should eq coupon.id
    end
  end

  describe '#assign_price_and_title' do
    it 'assigns the price and title as per the stripe plan and coupon' do
      subscription = Effective::Subscription.new()

      plan = ::Stripe::Plan.create(:id => 'stripe_plan', :name => 'Stripe Plan', :amount => 1000, :currency => 'USD', :interval => 'month')

      subscription.stripe_plan_id = plan.id

      subscription.price.should eq plan.amount
      subscription.title.include?(plan.name).should eq true
      subscription.title.include?(plan.interval).should eq true
    end

    it 'assigns the price and title as per the stripe plan and coupon amount off' do
      subscription = Effective::Subscription.new()

      plan = ::Stripe::Plan.create(:id => 'stripe_plan', :name => 'Stripe Plan', :amount => 1000, :currency => 'USD', :interval => 'month')
      coupon = ::Stripe::Coupon.create(:percent_off => 25)

      subscription.stripe_plan_id = plan.id
      subscription.stripe_coupon_id = coupon.id

      subscription.price.should eq (plan.amount * (coupon.percent_off.to_i / 100.0)).round(0).to_i
      subscription.title.include?('25% off').should eq true
    end

    it 'assigns the price and title as per the stripe plan and coupon percent off' do
      subscription = Effective::Subscription.new()

      plan = ::Stripe::Plan.create(:id => 'stripe_plan', :name => 'Stripe Plan', :amount => 1000, :currency => 'USD', :interval => 'month')
      coupon = ::Stripe::Coupon.create(:percent_off => nil, :amount_off => 100)

      subscription.stripe_plan_id = plan.id
      subscription.stripe_coupon_id = coupon.id

      subscription.price.should eq plan.amount - coupon.amount_off
      subscription.title.include?('$1.00 off').should eq true
    end
  end


end
