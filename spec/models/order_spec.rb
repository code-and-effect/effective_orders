require 'spec_helper'

describe Effective::Order, type: :model do
  let(:cart) { FactoryGirl.create(:cart) }
  let(:order) { FactoryGirl.create(:order) }
  let(:user) { FactoryGirl.create(:user) }
  let(:product) { FactoryGirl.create(:product) }
  let(:product2) { FactoryGirl.create(:product) }

  it 'calculates dollars based on its order items' do
    order.subtotal.should eq order.order_items.collect(&:subtotal).sum
    order.total.should eq (order.order_items.collect(&:subtotal).sum + order.tax.to_i)
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
      order.subtotal.should eq cart.subtotal
    end

    it 'creates appropriate OrderItems when initialized with an array of purchasables' do
      order = Effective::Order.new([product, product2])
      order.order_items.size.should eq 2

      order.subtotal.should eq (product.price + product2.price)
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

  describe 'minimum zero math' do
    it 'has a minimum order total of 0' do
      order.subtotal = nil
      order.total = nil

      order.order_items.each { |oi| oi.price = -1000; oi.tax_exempt = true; }
      order.order_items.collect(&:total).sum.should eq -3000

      order.total.should eq 0
    end

    it 'has no minimum subtotal' do
      order.subtotal = nil

      order.order_items.each { |oi| oi.price = -1000; oi.tax_exempt = true; }
      order.order_items.collect(&:subtotal).sum.should eq -3000

      order.subtotal.should eq -3000
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

      user.billing_address = FactoryGirl.create(:address, category: :billing)
      user.shipping_address = FactoryGirl.create(:address, category: :shipping)

      order.user = user

      order.billing_address.should eq user.billing_address
      order.save_billing_address.should eq true

      order.shipping_address.should eq user.shipping_address
      order.save_shipping_address.should eq true
    end
  end

  describe 'validations' do
    it 'should validate inclusion of purchase state' do
      expect(subject).to validate_inclusion_of(:purchase_state).in_array([nil, EffectiveOrders::PURCHASED, EffectiveOrders::DECLINED, EffectiveOrders::PENDING])
    end

    it 'should be invalid without a user or order_items' do
      order = Effective::Order.new()
      order.valid?.should eq false

      order.errors[:user_id].present?.should eq true
      order.errors[:order_items].present?.should eq true
    end

    it 'should be invalid when user is invalid' do
      allow(order.user).to receive(:valid?).and_return(false)
      order.valid?.should eq false

      order.errors[:user].present?.should eq true
    end

    it 'should be invalid when an order_item is invalid' do
      allow(order.order_items.first).to receive(:valid?).and_return(false)
      order.valid?.should eq false

      order.errors[:order_items].present?.should eq true
    end

    it 'should be invalid when less than the minimum charge' do
      order.order_items.each { |oi| oi.price = 1 }
      order.valid?.should eq false

      order.errors[:total].present?.should eq true
      order.errors[:total].first.downcase.include?('minimum order of 50 is required').should eq true
    end

    it 'should be valid when >= minimum charge' do
      allow(order).to receive(:total).and_return(50)
      order.valid?.should eq true

      allow(order).to receive(:total).and_return(51)
      order.valid?.should eq true
    end

    it 'should be valid for a free order' do
      order.order_items.each { |order_item| allow(order_item).to receive(:total).and_return(0) }

      order.valid?.should eq true
      order.errors[:total].present?.should eq false
    end
  end

  describe 'tax and tax rate' do
    it 'is invalid with no tax rate' do
      order = Effective::Order.new()
      order.tax_rate.should eq nil
      order.valid?.should eq false
      order.errors[:tax_rate].present?.should eq true
    end

    it 'is valid with no tax rate when skip_buyer_validations = true' do
      order = Effective::Order.new()
      order.skip_buyer_validations = true
      order.tax_rate.should eq nil
      order.errors[:tax_rate].present?.should eq false
    end

    it 'sets a tax rate when billing_address is present' do
      order = FactoryGirl.create(:order)
      order.billing_address.present?.should eq true
      order.valid?.should eq true
      order.errors[:tax_rate].blank?.should eq true
    end

    it 'updates the tax rate on valid? when billing_address changes' do
      order = FactoryGirl.create(:order)

      order.billing_address = FactoryGirl.create(:address, state_code: 'AB') # 5.0% tax
      order.valid?.should eq true
      order.tax_rate.should eq 5.0
      order.tax.should eq (order.subtotal * 0.05)
      order.total.should eq (order.subtotal + order.tax)
      total_one = order.total

      order.billing_address = FactoryGirl.create(:address, state_code: 'ON') # 13.0% tax
      order.valid?.should eq true
      order.tax_rate.should eq 13.0
      order.tax.should eq (order.subtotal * 0.13)
      order.total.should eq (order.subtotal + order.tax)
      total_two = order.total

      total_one.should_not eq total_two
    end

  end

  describe 'create_as_pending' do
    it 'sets the pending state' do
      order = FactoryGirl.build(:order)
      order.order_items << FactoryGirl.build(:order_item, order: order)

      order.create_as_pending.should eq true
      order.pending?.should eq true
    end

    it 'disregards invalid addresses' do
      order = FactoryGirl.build(:order)
      order.order_items << FactoryGirl.build(:order_item, order: order)

      order.billing_address = Effective::Address.new(address1: 'invalid')
      order.shipping_address = Effective::Address.new(address1: 'invalid')

      success = order.create_as_pending

      success.should eq true
    end

    it 'sends a request for payment when send_payment_request_to_buyer is true' do
      Effective::OrdersMailer.deliveries.clear

      order = FactoryGirl.build(:order)
      order.order_items << FactoryGirl.build(:order_item, order: order)

      order.send_payment_request_to_buyer = true

      order.create_as_pending.should eq true
      order.send_payment_request_to_buyer?.should eq true

      Effective::OrdersMailer.deliveries.length.should eq 1
    end

    it 'does not send a request for payment when send_payment_request_to_buyer is false' do
      Effective::OrdersMailer.deliveries.clear

      order = FactoryGirl.build(:order)
      order.order_items << FactoryGirl.build(:order_item, order: order)

      order.create_as_pending.should eq true

      Effective::OrdersMailer.deliveries.length.should eq 0
    end

  end

  describe 'save as pending' do
    let(:order) { FactoryGirl.build(:order, billing_address: FactoryGirl.build(:address), shipping_address: FactoryGirl.build(:address)) }

    it 'sets the pending state' do
      order.order_items << FactoryGirl.build(:order_item, order: order)

      order.purchase_state = EffectiveOrders::PENDING

      order.save.should eq true
      order.pending?.should eq true
    end

    it 'does not accept invalid addresses' do
      order.order_items << FactoryGirl.build(:order_item, order: order)

      order.billing_address = Effective::Address.new(address1: 'invalid')
      order.shipping_address = Effective::Address.new(address1: 'invalid')

      order.purchase_state = EffectiveOrders::PENDING

      order.save.should eq false
    end
  end

  describe 'purchase!' do
    it 'assigns the purchase_state, purchase_at and payment' do
      order.purchase!(details: 'by a test').should eq true

      order.purchase_state.should eq EffectiveOrders::PURCHASED
      order.purchased_at.kind_of?(Time).should eq true
      order.payment[:details].should eq 'by a test'
    end

    it 'sends purchased callback to all order_items' do
      order.order_items.each { |oi| oi.purchasable.should_receive(:purchased!).with(order, oi) }
      order.purchase!(details: 'by a test')
    end

    it 'returns true when purchased twice' do
      order.purchase!(details: 'first time by a test')
      order.purchase!(details: 'second time by a test').should eq false
    end

    it 'sends emails to the admin, buyer and seller' do
      Effective::OrdersMailer.deliveries.clear

      order.purchase!(details: 'by a test')

      Effective::OrdersMailer.deliveries.length.should eq 2

      Effective::OrdersMailer.deliveries[0].to.first.should eq 'admin@example.com'
      Effective::OrdersMailer.deliveries[0].subject.include?("Order ##{order.to_param} Receipt").should eq true

      Effective::OrdersMailer.deliveries[1].to.first.should eq order.user.email
      Effective::OrdersMailer.deliveries[1].subject.include?("Order ##{order.to_param} Receipt").should eq true
    end

    it 'does not send email if passed email: false' do
      Effective::OrdersMailer.deliveries.clear

      order.purchase!(details: 'by a test', email: false)

      Effective::OrdersMailer.deliveries.length.should eq 0
    end

    it 'is included with the purchased scope' do
      order.purchase!(details: 'by a test')
      Effective::Order.purchased.to_a.include?(order).should eq true
      Effective::Order.purchased_by(order.user).to_a.include?(order).should eq true
    end

    it 'is not included with the declined scope' do
      order.purchase!(details: 'by a test')
      Effective::Order.declined.to_a.include?(order).should eq false
    end

    it 'should return false when the Order is invalid' do
      allow(order).to receive(:valid?).and_return(false)
      expect { order.purchase!(details: 'by a test') }.to raise_exception(Exception)
    end

    it 'should return true when the Order is invalid and validate: false is passed' do
      allow(order).to receive(:valid?).and_return(false)
      order.purchase!(details: 'by a test', validate: false).should eq true
    end

  end

  describe 'purchased?' do
    it 'returns true when a purchased order' do
      order.purchase!(details: 'by a test')
      order.purchased?.should eq true
    end

    it 'returns false when not purchased' do
      order.purchased?.should eq false
    end

    it 'returns false when declined' do
      order.decline!(details: 'by a test')
      order.purchased?.should eq false
    end
  end

  describe 'decline!' do
    it 'assigns the purchase_state' do
      order.decline!(details: 'by a test').should eq true

      order.purchase_state.should eq EffectiveOrders::DECLINED
      order.payment[:details].should eq 'by a test'
      order.purchased_at.should eq nil
    end

    it 'sends declined callback to all order_items' do
      order.order_items.each { |oi| oi.purchasable.should_receive(:declined!).with(order, oi) }
      order.decline!(details: 'by a test')
    end

    it 'returns false when declined twice' do
      order.decline!(details: 'first time')
      order.decline!(details: 'second time').should eq false
    end

    it 'returns false when declined twice' do
      order.decline!(details: 'first time')
      order.decline!(details: 'second time').should eq false
    end

    it 'is included with the declined scope' do
      order.decline!(details: 'by a test')
      Effective::Order.declined.to_a.include?(order).should eq true
    end

    it 'is not included with the purchased scope' do
      order.decline!(details: 'by a test')
      Effective::Order.purchased.to_a.include?(order).should eq false
      Effective::Order.purchased_by(order.user).to_a.include?(order).should eq false
    end
  end

  describe 'declined?' do
    it 'returns true when a declined order' do
      order.decline!(details: 'by a test')
      order.declined?.should eq true
    end

    it 'returns false when not declined' do
      order.declined?.should eq false
    end

    it 'returns false when purchased' do
      order.purchase!(details: 'by a test')
      order.declined?.should eq false
    end
  end

  describe '#save_billing_address?' do
    it 'is true when save_billing_address is 1' do
      order.save_billing_address = '1'
      order.save_billing_address?.should eq true
    end

    it 'is false when save_billing_address is 0' do
      order.save_billing_address = '0'
      order.save_billing_address?.should eq false
    end

    it 'is false when save_billing_address is nil' do
      order.save_billing_address = nil
      order.save_billing_address?.should eq false
    end
  end

  describe '#save_shipping_address?' do
    it 'is true when save_shipping_address is 1' do
      order.save_shipping_address = '1'
      order.save_shipping_address?.should eq true
    end

    it 'is false when save_shipping_address is 0' do
      order.save_shipping_address = '0'
      order.save_shipping_address?.should eq false
    end

    it 'is false when save_shipping_address is nil' do
      order.save_shipping_address = nil
      order.save_shipping_address?.should eq false
    end
  end

  describe '#to_param' do
    it 'returns an obfuscated ID' do
      (order.to_param.length >= 10).should eq true
    end
  end

  describe '#pending?' do
    it 'should return true for pending orders only' do
      expect(FactoryGirl.create(:purchased_order).pending?).to be_falsey
      expect(FactoryGirl.create(:declined_order).pending?).to be_falsey
      expect(FactoryGirl.create(:pending_order).pending?).to be_truthy
    end
  end
end
