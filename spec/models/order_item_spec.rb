require 'spec_helper'

# # Attributes
describe Effective::OrderItem do
  let(:order) { FactoryGirl.create(:order) }
  let(:order_item) { FactoryGirl.create(:order_item) }

  describe 'validations' do
    it 'is invalid without required fields' do
      order_item = Effective::OrderItem.new()
      order_item.valid?.should eq false

      order_item.errors[:title].present?.should eq true
      order_item.errors[:quantity].present?.should eq true
      order_item.errors[:tax_exempt].present?.should eq true
      order_item.errors[:purchasable].present?.should eq true
    end
  end

  describe 'scopes' do
    it 'is included in the Sold scope when order is purchased' do
      order.purchase!('from a test')
      (order.order_items.size > 0).should eq true

      sold_items = Effective::OrderItem.sold.to_a
      sold_items.size.should eq order.order_items.size

      order.order_items.each { |oi| sold_items.include?(oi).should eq true }
    end

  end



end
