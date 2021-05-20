require 'test_helper'

class OrdersTest < ActiveSupport::TestCase

  test 'create a valid order' do
    order = create_effective_order!()
    assert order.valid?
  end

end
