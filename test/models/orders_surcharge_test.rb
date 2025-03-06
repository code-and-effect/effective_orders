require 'test_helper'

class OrdersPriceTest < ActiveSupport::TestCase

  # Purchase with credit card provider
  test 'purchase with credit card surcharge' do
    user = build_user_with_address()
    item = Effective::Product.new(name: 'One', price: 100_00, qb_item_name: 'Item 1')

    order = Effective::Order.new(user: user, items: item)
    assert order.save!

    assert_equal 2.4, order.surcharge_percent
    assert_equal 2_52, order.surcharge
    assert_equal 13, order.surcharge_tax
    assert_equal 107_65, order.total

    assert EffectiveOrders.credit_card_payment_providers.include?('credit card')

    assert order.purchase!(provider: 'credit card')

    assert_equal 2.4, order.surcharge_percent
    assert_equal 2_52, order.surcharge
    assert_equal 13, order.surcharge_tax
    assert_equal 107_65, order.total
  end

  test 'purchase without credit card surcharge' do
    user = build_user_with_address()
    item = Effective::Product.new(name: 'One', price: 100_00, qb_item_name: 'Item 1')

    order = Effective::Order.new(user: user, items: item)
    assert order.save!

    assert_equal 2.4, order.surcharge_percent
    assert_equal 2_52, order.surcharge
    assert_equal 13, order.surcharge_tax
    assert_equal 107_65, order.total

    assert EffectiveOrders.credit_card_payment_providers.exclude?('none')

    assert order.purchase!(provider: 'none')

    assert_equal 0.0, order.surcharge_percent
    assert_equal 0, order.surcharge
    assert_equal 0, order.surcharge_tax
    assert_equal 105_00, order.total
  end

end
