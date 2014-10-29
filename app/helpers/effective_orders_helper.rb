module EffectiveOrdersHelper
  def order_summary(order)
    content_tag(:p, "#{number_to_currency(order.total)} total for #{pluralize(order.num_items, 'item')}:") +

    content_tag(:ul) do
      order.order_items.map do |item|
        content_tag(:li) do
          title = item.title.split('<br>')
          "#{item.quantity}x #{title.first} for #{number_to_currency(item.price)}".tap do |output|
            title[1..-1].each { |line| output << "<br>#{line}" }
          end.html_safe
        end
      end.join().html_safe
    end
  end

  def order_item_summary(order_item)
    if order_item.quantity > 1
      content_tag(:p, "#{number_to_currency(order_item.total)} total for #{pluralize(order_item.quantity, 'item')}")
    else
      content_tag(:p, "#{number_to_currency(order_item.total)} total")
    end
  end

  # This is called on the My Sales Page and is intended to be overridden in the app if needed
  def acts_as_purchasable_path(purchasable, action = :show)
    polymorphic_path(purchasable)
  end

  def order_payment_to_html(order)
    payment = order.payment

    if order.purchased?(:stripe_connect) && order.payment.kind_of?(Hash)
      payment = Hash[
        order.payment.map do |seller_id, v|
          if (user = Effective::Customer.find(seller_id).try(:user))
            [link_to(user, admin_user_path(user)), order.payment[seller_id]]
          else
            [seller_id, order.payment[seller_id]]
          end
        end
      ]
    end

    content_tag(:pre) do
      raw JSON.pretty_generate(payment).html_safe
        .gsub('\"', '')
        .gsub("[\n\n    ]", '[]')
        .gsub("{\n    }", '{}')
    end
  end

  def render_checkout(order, opts = {})
    raise ArgumentError.new('unable to checkout an order without a user') unless order.user.present?

    locals = {
      :purchased_redirect_url => nil,
      :declined_redirect_url => nil
    }.merge(opts)

    if order.new_record?
      render(:partial => 'effective/orders/checkout_step_1', :locals => locals.merge({:order => order}))
    else
      raise ArgumentError.new('unable to checkout a persisted but invalid order') unless order.valid?
      render(:partial => 'effective/orders/checkout_step_2', :locals => locals.merge({:order => order}))
    end
  end

  def render_order_history(user_or_orders, opts = {})
    if user_or_orders.kind_of?(User)
      orders = Effective::Order.purchased_by(user_or_orders)
    elsif user_or_orders.respond_to?(:to_a)
      begin
        orders = user_or_orders.to_a.select { |order| order.purchased? }
      rescue => e
        raise ArgumentError.new('expecting an instance of User or an array/collection of Effective::Order objects')
      end
    else
      raise ArgumentError.new('expecting an instance of User or an array/collection of Effective::Order objects')
    end

    locals = {
      :orders => orders,
      :order_path => effective_orders.order_path(':id') # The :id string will be replaced with the order id
    }.merge(opts)

    render(:partial => 'effective/orders/my_purchases', :locals => locals)
  end

  alias_method :render_purchases, :render_order_history
  alias_method :render_my_purchases, :render_order_history

end
