require 'test_helper'

class OrdersTest < ActiveSupport::TestCase

  test 'create a valid order' do
    order = create_effective_order!()
    assert order.valid?
    assert order.pending?

    assert_equal 2, order.order_items.length

    assert order.user.present?
    assert order.billing_address.present?
    assert order.shipping_address.present?

    assert_equal 300, order.subtotal

    assert_equal 5.0, order.tax_rate
    assert_equal 15, order.tax

    assert_equal 315, order.amount_owing

    assert_equal 2.4, order.surcharge_percent
    assert_equal 8, order.surcharge
    assert_equal 0, order.surcharge_tax

    assert_equal 323, order.total
  end

  test 'sends an email when purchased' do
    order = create_effective_order!()

    assert order.send_order_receipt_to_buyer?
    assert order.send_order_receipt_to_admin?

    assert_email(count: 2) { order.purchase! }
  end

  test 'sends an email when declined' do
    order = create_effective_order!()

    assert order.send_order_declined_to_buyer?
    assert order.send_order_declined_to_admin?

    assert_email(count: 2) { order.decline!(email: true) }
  end

  test 'sends a payment request when pending' do
    order = create_effective_order!()
    order.send_payment_request_to_buyer = true

    assert order.send_payment_request_to_buyer?

    assert_email { order.pending! }
  end

  test 'assigned purchased by when purchased' do
    order = create_effective_order!()
    user = order.user

    assert order.purchased_by.blank?

    order.purchase!(current_user: user)

    assert_equal user, order.purchased_by
  end

end
