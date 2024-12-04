module EffectiveOrdersTestBuilder
  def create_thing!
    build_thing.tap { |thing| thing.save! }
  end

  def build_thing
    thing = Thing.new(
      title: 'Thing',
      price: 100_00,
      tax_exempt: false,
      qb_item_name: 'Thing'
    )
  end

  def create_effective_order!
    build_effective_order.tap { |order| order.save! }
  end

  def build_effective_order(user: nil, organization: nil, items: nil, billing_address: nil, shipping_address: nil)
    user ||= create_user!
    items ||= [build_effective_product, build_effective_product]
    billing_address ||= build_effective_address(category: 'billing')
    shipping_address ||= build_effective_address(category: 'shipping')

    order = Effective::Order.new(
      user: user,
      organization: organization,
      items: items,
      billing_address: billing_address,
      shipping_address: shipping_address
    )

    order
  end

  def build_effective_refund_order(user: nil, organization: nil, items: nil, billing_address: nil, shipping_address: nil)
    user ||= create_user!
    items ||= [build_effective_product, build_effective_product]
    billing_address ||= build_effective_address(category: 'billing')
    shipping_address ||= build_effective_address(category: 'shipping')

    items.each { |item| item.price = -item.price}

    order = Effective::Order.new(
      user: user,
      organization: organization,
      items: items,
      billing_address: billing_address,
      shipping_address: shipping_address
    )

    order
  end

  def create_effective_product!
    build_effective_product.tap { |product| product.save! }
  end

  def build_effective_product
    @product_index ||= 0
    @product_index += 1

    product = Effective::Product.new(
      name: "Item #{@product_index}",
      price: (100 * @product_index),
      tax_exempt: false
    )

    product
  end

  def build_preview_order
    order = Effective::Order.new(id: 1)
    order.user = preview_user
    preview_order_items.each { |atts| order.order_items.build(atts) }

    order.state = 'purchased'
    order.payment_card = 'visa'
    order.purchased_at = Time.zone.now
    order.payment = { 'f4l4' => '1234'}

    order.valid?
    order
  end

  def create_effective_address!
    build_effective_address.tap { |address| address.save! }
  end

  def build_effective_address(category: 'billing')
    address = Effective::Address.new(
      category: category,
      full_name: 'Valued Customer',
      address1: '1234 Fake Street',
      address2: 'Suite 200',
      city: 'Edmonton',
      state_code: 'AB',
      country_code: 'CA',
      postal_code: 'T5T 2T1'
    )

    address
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

  def build_user_with_address
    user = build_user()

    user.addresses.build(
      addressable: user,
      category: 'billing',
      full_name: 'Test User',
      address1: '1234 Fake Street',
      city: 'Victoria',
      state_code: 'BC',
      country_code: 'CA',
      postal_code: 'H0H0H0'
    )

    user.save!
    user
  end

end
