require 'test_helper'

class OrdersRestrictionsTest < ActiveSupport::TestCase
  test 'payment restrictions' do
    order = create_effective_order!()
    assert_equal 3_23, order.total

    assert EffectiveOrders.payment_restriction(:cheque, order).blank?

    with_max_price_payment_restrictions do
      assert EffectiveOrders.payment_restriction(:cheque, order).include?('up to $3.00')
    end

    with_min_price_payment_restrictions do
      assert EffectiveOrders.payment_restriction(:cheque, order).include?('over $4.00')
    end
  end

  def with_max_price_payment_restrictions
    value = EffectiveOrders.cheque

    begin
      EffectiveOrders.cheque = { max_price: 3_00 }
      yield
    ensure
      EffectiveOrders.cheque = value
    end
  end

  def with_min_price_payment_restrictions
    value = EffectiveOrders.cheque

    begin
      EffectiveOrders.cheque = { min_price: 4_00 }
      yield
    ensure
      EffectiveOrders.cheque = value
    end
  end

end
