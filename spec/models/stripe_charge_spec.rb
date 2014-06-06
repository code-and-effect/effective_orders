require 'spec_helper'

# # Attributes
describe Effective::StripeCharge do
  let(:order) { FactoryGirl.create(:order_with_subscription) }
  let(:charge) { Effective::StripeCharge.new(order) }

  before { StripeMock.start }
  after { StripeMock.stop }

  it 'can be initialized with an order' do
    charge = Effective::StripeCharge.new(order)
    charge.order.should eq order
    charge.effective_order_id.should eq order.id
  end

  it 'can be initialized without an order' do
    charge = Effective::StripeCharge.new(:token => 'tok_123', :effective_order_id => 3)
    charge.token.should eq 'tok_123'
    charge.effective_order_id.should eq 3
    charge.order.nil?.should eq true
  end

  it 'performs validations' do
    charge = Effective::StripeCharge.new()
    charge.valid?.should eq false
    charge.errors[:token].present?.should eq true
    charge.errors[:effective_order_id].present?.should eq true
  end

  it '#order_items returns all OrderItems where the purchasable is not a Subscription' do
    charge.order_items.all? { |oi| oi.purchasable_type != 'Effective::Subscription'}.should eq true
  end

  it '#subscriptions returns all Subscriptions (not order items)' do
    charge.subscriptions.all? { |oi| oi.kind_of?(Effective::Subscription) }.should eq true
  end

end
