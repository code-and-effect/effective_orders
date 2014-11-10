require 'spec_helper'

# # Attributes
describe Product do
  let(:user) { FactoryGirl.create(:user) }
  let(:order) { FactoryGirl.create(:order) }
  let(:product) { order.order_items.first.purchasable }
  let(:product_with_float_price) { FactoryGirl.create(:product_with_float_price) }

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

  describe 'float prices' do
    it 'should automatically convert float prices to integer' do
      product_with_float_price.price = 20.00
      product_with_float_price.tax_exempt = true

      order = Effective::Order.new(product_with_float_price, user)

      order.subtotal.should eq 2000
      order.tax.should eq 0
      order.total.should eq 2000
    end

    it 'should automatically convert tax floats to integers' do
      product_with_float_price.price = 20.00
      product_with_float_price.tax_exempt = false

      order = Effective::Order.new(product_with_float_price, user)

      order.subtotal.should eq 2000
      order.tax.should eq 100
      order.total.should eq 2100
    end

  end

end
