require 'test_helper'

class ActsAsPurchasableTest < ActiveSupport::TestCase
  test 'things factory' do
    thing = create_thing!
    assert thing.valid?
    refute thing.purchased?

    assert thing.respond_to?(:purchased_at=)
    assert thing.respond_to?(:purchased_by=)
  end

  test 'products factory' do
    product = create_effective_product!
    assert product.valid?
    refute product.purchased?

    refute product.respond_to?(:purchased_at=)
    refute product.respond_to?(:purchased_by=)
  end

  test 'assigns purchased at to purchasable' do
    thing = create_thing!
    product = create_effective_product!

    order = build_effective_order(items: [thing, product])
    user = order.user
    order.mark_as_purchased!(current_user: user)

    assert_equal order.purchased_at, thing.purchased_at
    assert_equal user, thing.purchased_by
    assert thing.purchased_by?(user)

    assert_equal order.purchased_at, thing.purchased_at
    assert thing.purchased_by?(user)
  end

end
