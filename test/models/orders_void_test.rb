require 'test_helper'

class OrdersTest < ActiveSupport::TestCase

  test 'voiding an order' do
    order = create_effective_order!()
    assert order.void!

    assert_equal 'voided', order.status
    assert order.voided?

    assert order.unvoid!
    assert_equal 'pending', order.status
    refute order.voided?
  end

  test 'void order cannot be purchased' do
    order = create_effective_order!()
    assert order.void!

    assert_raises(Exception) { order.purchase! }
  end

  test 'void and unvoid a pending order' do
    # Pending order
    order = create_effective_order!()
    assert order.pending?

    # Void it
    assert order.void!
    assert order.voided?
    assert order.was_pending?
    refute order.pending?

    # Remove void entirely
    assert order.unvoid!
    refute order.voided?
    refute order.was_voided?

    # Back to pending
    assert order.pending?
  end

  test 'void and unvoid a purchased order' do
    # Pending order
    order = create_effective_order!()
    order.mark_as_purchased!

    assert order.purchased?

    # Void it
    assert order.void!
    assert order.voided?
    assert order.was_purchased?
    refute order.purchased?

    # Remove void entirely
    assert order.unvoid!
    refute order.was_voided?
    refute order.voided?

    # Back to purchased
    assert order.purchased?
    assert order.was_purchased?
  end

end
