require 'test_helper'

class OrdersPriceTest < ActiveSupport::TestCase

  # An order of $100.00 has $5.00 tax (100 * 1.05) and a $2.52 surcharge (105*1.024) and $0.13 surcharge tax ($2.51*0.05) and totals $107.65 (order + tax + surcharge + surcharge tax)
  test 'one hundred dollar order' do
    user = build_user_with_address()
    item1 = Effective::Product.new(name: 'One', price: 50_00)
    item2 = Effective::Product.new(name: 'Two', price: 50_00)

    order = Effective::Order.new(user: user, items: [item1, item2])
    assert order.save!

    # Subtotal
    assert_equal 100_00, order.subtotal

    # 5.0% tax rate
    assert_equal 5.0, order.tax_rate
    assert_equal 5_00, order.tax

    # Amount owing is Subtotal + Tax
    assert_equal 105_00, order.amount_owing

    # 2.4% surcharge
    assert_equal 2.4, order.surcharge_percent
    assert_equal 2_52, order.surcharge

    # Surcharge Tax is 5.0 tax on 2_52
    assert_equal 13, order.surcharge_tax

    # Total is subtotal + tax + surcharge
    assert_equal 107_65, order.total
  end

  # An order of $100.00 has $5.00 tax (100 * 1.05) and a $1.58 surcharge (105*1.024) and $0.08 surcharge tax ($2.51*0.05) and totals $106.66 (order + tax + surcharge + surcharge tax)
  test 'one hundred dollar order with 1.5 percent processing fee (telus example)' do
    user = build_user_with_address()
    item1 = Effective::Product.new(name: 'One', price: 50_00)
    item2 = Effective::Product.new(name: 'Two', price: 50_00)

    order = Effective::Order.new(user: user, items: [item1, item2])
    with_surcharge_percent(1.5) { assert order.save! }

    # Subtotal
    assert_equal 100_00, order.subtotal

    # 5.0% tax rate
    assert_equal 5.0, order.tax_rate
    assert_equal 5_00, order.tax

    # Amount owing is Subtotal + Tax
    assert_equal 105_00, order.amount_owing

    # 1.5% surcharge
    assert_equal 1.5, order.surcharge_percent
    assert_equal 1_58, order.surcharge

    # Surcharge Tax is 5.0 tax on 1.58
    assert_equal 8, order.surcharge_tax

    # Total is subtotal + tax + surcharge
    assert_equal 106_66, order.total
  end

  # An order of $325.00 has $16.25 tax (325 * 0.05) and a $8.19 surcharge (341.25 * 0.024) and $0.41 surcharge tax (8.19 * 0.05) and totals $349.85 (order + tax + surcharge + surcharge tax)
  test 'three hundred twenty five dollar order' do
    user = build_user_with_address()
    item1 = Effective::Product.new(name: 'One', price: 325_00)

    order = Effective::Order.new(user: user, items: item1)
    assert order.save!

    # Subtotal
    assert_equal 325_00, order.subtotal

    # 5.0% tax rate
    assert_equal 5.0, order.tax_rate
    assert_equal 16_25, order.tax

    # Amount owing is Subtotal + Tax
    assert_equal 341_25, order.amount_owing

    # 2.4% surcharge
    assert_equal 2.4, order.surcharge_percent
    assert_equal 8_19, order.surcharge

    # Surcharge Tax
    assert_equal 41, order.surcharge_tax

    # Total is subtotal + tax + surcharge + surcharge tax
    assert_equal 349_85, order.total
  end

  private

  def with_surcharge_percent(percent)
    existing = EffectiveOrders.credit_card_surcharge_percent

    begin
      EffectiveOrders.credit_card_surcharge_percent = percent
      yield
    ensure
      EffectiveOrders.credit_card_surcharge_percent = existing
    end
  end

end
