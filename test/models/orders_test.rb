require 'test_helper'

class OrdersTest < ActiveSupport::TestCase

  test 'create a valid order' do
    order = create_effective_order!()
    assert order.valid?

    assert_equal 2, order.order_items.length

    assert order.user.present?
    assert order.billing_address.present?
    assert order.shipping_address.present?

    assert_equal 315, order.total
    assert_equal 300, order.subtotal
    assert_equal 15, order.tax
    assert_equal 5.0, order.tax_rate
  end

end
