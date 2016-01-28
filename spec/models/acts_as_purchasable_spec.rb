require 'spec_helper'

# # Attributes
describe Product do
  let(:user) { FactoryGirl.create(:user) }
  let(:order) { FactoryGirl.create(:order) }
  let(:product) { order.order_items.first.purchasable }
  let(:product_with_float_price) { FactoryGirl.create(:product_with_float_price) }

  describe 'assumptions' do
    it 'should be effectively purchasable' do
      product.kind_of?(ActsAsPurchasable).should eq true
    end
  end

  describe 'purchased' do
    it 'is purchased? when in a purchased Order' do
      order.purchase!

      product.purchased?.should eq true
      product.purchased_orders.include?(order).should eq true
    end

    it 'is purchased? in the after_purchase callback' do
      instance_order = nil
      instance_product = nil
      instance_purchased = nil

      Product.instance_eval do
        after_purchase do |order, order_item|
          if defined?(:instance_order)
            instance_order = order
            instance_product = self
            instance_purchased = self.purchased?
          end
        end
      end

      order.purchase!

      instance_order.purchased?.should eq true
      instance_product.purchased?.should eq true
      instance_purchased.should eq true
    end

    it 'is returned by the purchased scopes' do
      order.purchase!

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

      order = Effective::Order.new(product_with_float_price, user: user)
      order.billing_address = FactoryGirl.create(:address, state_code: 'AB')

      order.subtotal.should eq 2000
      order.tax.should eq 0
      order.total.should eq 2000
    end

    it 'should automatically convert tax floats to integers' do
      product_with_float_price.price = 20.00
      product_with_float_price.tax_exempt = false

      order = Effective::Order.new(product_with_float_price, user: user)
      order.billing_address = FactoryGirl.create(:address, state_code: 'AB')

      order.subtotal.should eq 2000
      order.tax.should eq 100
      order.total.should eq 2100
    end
  end

  describe 'price=' do
    it 'should accept an integer price' do
      product = Product.new()
      product.price = 1250

      product.price.should eq 1250
    end

    it 'should convert a String that looks like an Integer' do
      product = Product.new()
      product.price = '1250'

      product.price.should eq 1250
    end

    it 'should convert a String that looks like a Float' do
      product = Product.new()
      product.price = '12.50'

      product.price.should eq 1250
    end

    it 'should convert from a Float' do
      product = Product.new()
      product.price = 12.50
      product.price.should eq 1250

      product.price = Float(12.50)
      product.price.should eq 1250
    end

    it 'should convert from a BigDecimal' do
      product = Product.new()
      product.price = BigDecimal.new(12.5, 4)

      product.price.should eq 1250
    end

    it 'should treat nil as a zero' do
      product = Product.new()
      product.price = nil

      product.price.should eq 0
    end

  end

end
