require 'test_helper'

class OrdersPriceTest < ActiveSupport::TestCase

  # An order of $100.00 has $5.00 tax (100 * 1.05) and a $2.52 surcharge (105*1.024) and totals $107.52 (order + tax + surcharge)
  test 'order amounts with tax and surcharge' do
    user = build_user_with_address()
    item1 = Effective::Product.new(name: 'One', price: 50_00)
    item2 = Effective::Product.new(name: 'Two', price: 50_00)

    order = Effective::Order.new(user: user, items: [item1, item1])
    assert order.save!

    # Subtotal
    assert_equal 100_00, order.subtotal

    # 5.0% tax rate
    assert_equal 5.0, order.tax_rate
    assert_equal 5_00, order.tax

    # 2.4% surcharge
    assert_equal 2.4, order.surcharge_percent
    assert_equal 2_52, order.surcharge

    # Total is subtotal + tax + surcharge
    assert_equal 107_52, order.total
  end
end
