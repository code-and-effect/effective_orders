require 'spec_helper'

# # Attributes
describe Product do
  let(:order) { FactoryGirl.create(:order) }
  let(:product) { order.order_items.first.purchasable }

  describe 'assumptions' do
    it 'should be effectively purchasable' do
      product.is_effectively_purchasable?.should eq true
    end
  end

  describe 'purchased' do
    it 'is purchased? when in a purchased Order' do
      order.purchase!('by a test')

      product.purchased?.should eq true
      product.purchased_orders.include?(order).should eq true
    end

    it 'is returned by the purchased scopes' do
      order.purchase!('by a test')

      Product.purchased.to_a.include?(product).should eq true
      Product.purchased_by(order.user).to_a.include?(product).should eq true

      Product.sold.to_a.include?(product).should eq true

      Product.not_purchased.to_a.include?(product).should eq false
    end
  end
end
