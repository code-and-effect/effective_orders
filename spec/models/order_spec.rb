require 'spec_helper'

describe Effective::Order do
  let(:cart) { FactoryGirl.create(:cart) }
  let(:order) { FactoryGirl.create(:order) }
  let(:user) { FactoryGirl.create(:user) }
  let(:product) { FactoryGirl.create(:product) }
  let(:product2) { FactoryGirl.create(:product) }

  it 'calculates dollars based on its order items' do
    order.total.should eq order.order_items.collect(&:total).sum
    order.subtotal.should eq order.order_items.collect(&:subtotal).sum
    order.tax.should eq order.order_items.collect(&:tax).sum
    order.num_items.should eq order.order_items.collect(&:quantity).sum
  end

  describe '#initialize' do
    it 'creates appropriate OrderItems when initialized with a Cart' do
      order = Effective::Order.new(cart)

      order.order_items.each_with_index do |order_item, x|
        order_item.title.should eq cart.cart_items[x].title
        order_item.price.should eq cart.cart_items[x].price
        order_item.quantity.should eq cart.cart_items[x].quantity
        order_item.purchasable.should eq cart.cart_items[x].purchasable
      end

      order.order_items.length.should eq cart.cart_items.length
      order.total.should eq cart.total
      order.subtotal.should eq cart.subtotal
      order.tax.should eq cart.tax
    end

    it 'creates appropriate OrderItems when initialized with an array of purchasables' do
      order = Effective::Order.new([product, product2])
      order.order_items.size.should eq 2

      order.subtotal.should eq (product.price + product2.price)
      order.total.should eq ((product.price + product2.price) * 1.05)
    end

    it 'creates appropriate OrderItems when initialized with a single purchasable' do
      order = Effective::Order.new(product)
      order.order_items.size.should eq 1

      order_item = order.order_items.first

      order_item.title.should eq product.title
      order_item.price.should eq product.price
      order_item.purchasable.should eq product
      order_item.quantity.should eq 1
    end

    it 'throws an ArgumentError when passed something unexpected' do
      expect { Effective::Order.new(Object.new()) }.to raise_error(ArgumentError)
    end
  end

  describe 'user=' do
    it 'assigns the user' do
      order = Effective::Order.new()
      order.user = user
      order.user.should eq user
    end

    it 'assigns addresses from the user' do
      order = Effective::Order.new()

      user.billing_address = FactoryGirl.create(:address, :category => :billing)
      user.shipping_address = FactoryGirl.create(:address, :category => :shipping)

      order.user = user

      order.billing_address.should eq user.billing_address
      order.save_billing_address.should eq true

      order.shipping_address.should eq user.shipping_address
      order.save_shipping_address.should eq true
    end
  end

  describe 'validations' do
    it 'should be invalid without a user or order_items' do
      order = Effective::Order.new()
      order.valid?.should eq false

      order.errors[:user_id].present?.should eq true
      order.errors[:order_items].present?.should eq true
    end
  end

  describe 'purchase!' do
    it 'assigns the purchase_state, purchase_at and payment' do
      order.purchase!('by a test').should eq true

      order.purchase_state.should eq EffectiveOrders::PURCHASED
      order.purchased_at.kind_of?(Time).should eq true
      order.payment[:details].should eq 'by a test'
    end

    it 'sends purchased callback to all order_items' do
      order.order_items.each { |oi| oi.should_receive(:purchased).with(order).and_return(true) }
      order.purchase!('by a test')
    end

    it 'throws an error when purchased twice' do
      order.purchase!('first time')

      expect { order.purchase!('second time') }.to raise_error(EffectiveOrders::AlreadyPurchasedException)
    end

    it 'sends emails to the admin, buyer and seller' do
      Effective::OrdersMailer.should_receive(:order_receipt_to_admin).with(order)
      Effective::OrdersMailer.should_receive(:order_receipt_to_buyer).with(order)

      order.purchase!('by a test')
    end

    it 'is included with the purchased scope' do
      order.purchase!('by a test')
      Effective::Order.purchased.to_a.include?(order).should eq true
      Effective::Order.purchased_by(order.user).to_a.include?(order).should eq true
    end

    it 'is not included with the declined scope' do
      order.purchase!('by a test')
      Effective::Order.declined.to_a.include?(order).should eq false
    end
  end

  describe 'purchased?' do
    it 'returns true when a purchased order' do
      order.purchase!('by a test')
      order.purchased?.should eq true
    end

    it 'returns false when not purchased' do
      order.purchased?.should eq false
    end

    it 'returns false when declined' do
      order.decline!('by a test')
      order.purchased?.should eq false
    end
  end

  describe 'decline!' do
    it 'assigns the purchase_state' do
      order.decline!('by a test').should eq true

      order.purchase_state.should eq EffectiveOrders::DECLINED
      order.payment[:details].should eq 'by a test'
      order.purchased_at.should eq nil
    end

    it 'sends declined callback to all order_items' do
      order.order_items.each { |oi| oi.should_receive(:declined).with(order).and_return(true) }
      order.decline!('by a test')
    end

    it 'throws an error when declined twice' do
      order.decline!('first time')

      expect { order.decline!('second time') }.to raise_error(EffectiveOrders::AlreadyDeclinedException)
    end

    it 'is included with the declined scope' do
      order.decline!('by a test')
      Effective::Order.declined.to_a.include?(order).should eq true
    end

    it 'is not included with the purchased scope' do
      order.decline!('by a test')
      Effective::Order.purchased.to_a.include?(order).should eq false
      Effective::Order.purchased_by(order.user).to_a.include?(order).should eq false
    end
  end

  describe 'declined?' do
    it 'returns true when a declined order' do
      order.decline!('by a test')
      order.declined?.should eq true
    end

    it 'returns false when not declined' do
      order.declined?.should eq false
    end

    it 'returns false when purchased' do
      order.purchase!('by a test')
      order.declined?.should eq false
    end
  end

end
