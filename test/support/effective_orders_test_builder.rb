module EffectiveOrdersTestBuilder
  def create_effective_order!
    build_effective_order.tap { |order| order.save! }
  end

  def build_effective_order(user: nil)
    user ||= create_user!

    order = Effective::Order.new(
      user: user
    )

    order
  end

  def create_user!
    build_user.tap { |user| user.save! }
  end

  def build_user
    @user_index ||= 0
    @user_index += 1

    User.new(
      email: "user#{@user_index}@example.com",
      password: 'rubicon2020',
      password_confirmation: 'rubicon2020',
      first_name: 'Test',
      last_name: 'User'
    )
  end

end
