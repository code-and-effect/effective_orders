require 'spec_helper'

# Attributes
describe 'Factories' do
  let(:factories) { [:user, :customer, :subscription, :address, :product, :cart, :order_item, :order, :purchased_order, :declined_order, :cart_with_subscription, :order_with_subscription] }

  before { StripeMock.start }
  after { StripeMock.stop }

  it 'should have all valid factories' do
    factories.each do |factory|
      obj = FactoryGirl.create(factory)

      puts "Invalid factory #{factory}: #{obj.errors.inspect}" unless obj.valid?

      obj.valid?.should eq true
    end
  end

  it 'should have created an Order with a billing_address and shipping_address' do
    order = FactoryGirl.create(:order)

    order.billing_address.present?.should eq true
    order.shipping_address.present?.should eq true

    order.billing_address.valid?.should eq true
    order.shipping_address.valid?.should eq true

    order.billing_address.full_name.present?.should eq true
    order.shipping_address.full_name.present?.should eq true

    order.save.should eq true
  end

end
