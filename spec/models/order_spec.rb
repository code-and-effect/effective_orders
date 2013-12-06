require 'spec_helper'

describe Effective::Order do
  let(:cart) { FactoryGirl.create(:cart) }

  it 'should create appropriate OrderItems when initialized with a Cart' do
    new_order = Effective::Order.new(cart)

    new_order.order_items.each_with_index do |order_item, x|
      order_item.title.should eq cart.cart_items[x].title
      order_item.price.should eq cart.cart_items[x].price
      order_item.quantity.should eq cart.cart_items[x].quantity
      order_item.purchasable.should eq cart.cart_items[x].purchasable
    end

    new_order.order_items.length.should eq cart.cart_items.length
    new_order.total.should eq cart.total
    new_order.subtotal.should eq cart.subtotal
    new_order.tax.should eq cart.tax
  end



end
