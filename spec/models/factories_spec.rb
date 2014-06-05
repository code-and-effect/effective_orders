require 'spec_helper'

# Attributes
describe 'Factories' do
  let(:factories) { [:user, :customer, :subscription, :address, :product, :cart, :order_item, :order, :purchased_order, :declined_order] }

  before { StripeMock.start }
  after { StripeMock.stop }

  it 'should have all valid factories' do
    factories.each { |factory| FactoryGirl.create(factory).valid?.should eq true }
  end
end
