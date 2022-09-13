module EffectiveOrdersHelper
  def price_to_currency(price)
    price = price || 0
    raise 'price_to_currency expects an Integer representing the number of cents' unless price.kind_of?(Integer)
    number_to_currency(price / 100.0)
  end

  def tax_rate_to_percentage(tax_rate, options = {})
    options[:strip_insignificant_zeros] = true if options[:strip_insignificant_zeros].nil?
    number_to_percentage(tax_rate, strip_insignificant_zeros: true)
  end

  def order_summary(order)
    order_item_list = content_tag(:ul) do
      order.order_items.map do |item|
        content_tag(:li) do
          names = item.name.split('<br>')
          "#{item.quantity}x #{names.first} for #{price_to_currency(item.price)}".tap do |output|
            names[1..-1].each { |line| output << "<br>#{line}" }
          end.html_safe
        end
      end.join.html_safe
    end
    content_tag(:p, "#{price_to_currency(order.total)} total for #{pluralize(order.num_items, 'item')}:") + order_item_list
  end

  def order_item_summary(order_item)
    if order_item.quantity > 1
      content_tag(:p, "#{price_to_currency(order_item.total)} total for #{pluralize(order_item.quantity, 'item')}")
    else
      content_tag(:p, "#{price_to_currency(order_item.total)} total")
    end
  end

  def order_checkout_label(processor = nil)
    case processor
    when :cheque
      'Pay by Cheque'
    when :etransfer
      'Pay by E-transfer'
    when :free
      'Checkout Free'
    when :mark_as_paid
      'Admin: Mark as Paid'
    when :moneris
      'Checkout with Credit Card'
    when :moneris_checkout
      'Pay Now' # Doesn't get displayed anyway
    when :paypal
      'Checkout with PayPal'
    when :phone
      'Pay by Phone'
    when :pretend
      'Purchase Order (skip payment processor)'
    when :refund
      'Accept Refund'
    when :stripe
      'Pay Now'
    else
      'Checkout'
    end
  end

  # This is called on the My Sales Page and is intended to be overridden in the app if needed
  def acts_as_purchasable_path(purchasable, action = :show)
    polymorphic_path(purchasable)
  end

  def order_payment_to_html(order)
    content_tag(:pre) do
      raw JSON.pretty_generate(order.payment).html_safe.gsub('\"', '').gsub("[\n\n    ]", '[]').gsub("{\n    }", '{}')
    end
  end

  def render_order(order)
    render(partial: 'effective/orders/order', locals: { order: order })
  end

  def render_checkout(order, namespace: nil, purchased_url: nil, declined_url: nil, deferred_url: nil)
    raise 'unable to checkout an order without a user' unless order && order.user

    locals = { order: order, purchased_url: purchased_url, declined_url: declined_url, deferred_url: deferred_url, namespace: namespace }

    if order.purchased?
      render(partial: 'effective/orders/order', locals: locals)
    elsif (order.confirmed? || order.deferred?) && order.errors.blank?
      render(partial: 'effective/orders/checkout_step2', locals: locals)
    else
      render(partial: 'effective/orders/checkout_step1', locals: locals)
    end
  end

  def render_checkout_step1(order, namespace: nil, purchased_url: nil, declined_url: nil, deferred_url: nil)
    locals = { order: order, purchased_url: purchased_url, declined_url: declined_url, deferred_url: deferred_url, namespace: namespace }
    render(partial: 'effective/orders/checkout_step1', locals: locals)
  end

  def render_checkout_step2(order, namespace: nil, purchased_url: nil, declined_url: nil, deferred_url: nil)
    locals = { order: order, purchased_url: purchased_url, declined_url: declined_url, deferred_url: deferred_url, namespace: namespace }
    render(partial: 'effective/orders/checkout_step2', locals: locals)
  end

  def checkout_step1_form_url(order, namespace = nil)
    raise 'expected an order' unless order
    raise 'invalid namespace, expecting nil or :admin' unless [nil, :admin].include?(namespace)

    if order.new_record?
      namespace == nil ? effective_orders.orders_path : effective_orders.admin_orders_path
    else
      namespace == nil ? effective_orders.order_path(order) : effective_orders.checkout_admin_order_path(order)
    end
  end

  def render_orders(orders, opts = {})
    render(partial: 'effective/orders/orders_table', locals: { orders: orders }.merge(opts))
  end

  def checkout_icon_to(path, options = {})
    icon_to('shopping-cart', path, { title: 'Checkout' }.merge(options))
  end

end
