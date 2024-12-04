require 'test_helper'

class OrdersRefundTest < ActiveSupport::TestCase

  def with_refunds
    value = EffectiveOrders.refund

    begin
      EffectiveOrders.refund = { success: "Okay" }
      yield
    ensure
      EffectiveOrders.refund = value
    end
  end

  def without_refunds
    value = EffectiveOrders.refund

    begin
      EffectiveOrders.refund = false
      yield
    ensure
      EffectiveOrders.refund = value
    end
  end

  test 'create a refund order with EffectiveOrders.refunds true' do
    with_refunds do
      order = build_effective_refund_order()
      assert order.pending?

      assert order.order_items.all? { |order_item| order_item.price < 0 }
      assert order.purchasables.all? { |purchasable| purchasable.price < 0 }
      assert order.refund?
      refute order.free?

      order.save!

      order.reload
      assert order.order_items.all? { |order_item| order_item.price < 0 }
      assert order.purchasables.all? { |purchasable| purchasable.price < 0 }
      assert order.refund?
      refute order.free?

      assert_equal -3_00, order.order_items.sum(&:price)
      assert_equal -3_00, order.subtotal
      assert_equal -15, order.tax
      assert_equal -3_15, order.amount_owing
      assert_equal -8, order.surcharge
      assert_equal -3_23, order.total
    end
  end

  test 'create a refund order with EffectiveOrders.refunds false' do
    without_refunds do
      order = build_effective_refund_order()

      assert order.order_items.all? { |order_item| order_item.price < 0 }
      assert order.purchasables.all? { |purchasable| purchasable.price < 0 }
      refute order.refund?
      assert order.free?

      order.save!

      order.reload
      assert order.order_items.all? { |order_item| order_item.price < 0 }
      assert order.purchasables.all? { |purchasable| purchasable.price < 0 }
      refute order.refund?
      assert order.free?

      assert_equal -3_00, order.order_items.sum(&:price)
      assert_equal 0, order.subtotal
      assert_equal 0, order.tax
      assert_equal 0, order.amount_owing
      assert_equal 0, order.surcharge
      assert_equal 0, order.total
    end
  end

end
