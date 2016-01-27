module EffectiveOrdersHelper
  def price_to_currency(price)
    raise 'price_to_currency expects an Integer representing the number of cents in a price' unless price.kind_of?(Integer)
    number_to_currency(price / 100.0)
  end

  def order_summary(order)
    order_item_list = content_tag(:ul) do
      order.order_items.map do |item|
        content_tag(:li) do
          title = item.title.split('<br>')
          "#{item.quantity}x #{title.first} for #{price_to_currency(item.price)}".tap do |output|
            title[1..-1].each { |line| output << "<br>#{line}" }
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
    return 'Checkout' if (EffectiveOrders.single_payment_processor? && processor != :pretend)

    case processor
    when :free
      'Checkout'
    when :moneris
      'Checkout with Moneris'
    when :paypal
      'Checkout with PayPal'
    when :pretend  # The logic for this is in orders/views/_checkout_step_2.html.haml
      EffectiveOrders.allow_pretend_purchase_in_production ? 'Purchase Order' : 'Purchase Order (development only)'
    when :stripe
      'Checkout with Stripe'
    when :ccbill
      'Checkout with CCBill'
    when :app_checkout
      EffectiveOrders.app_checkout[:checkout_label]
    else
      'Checkout'
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

  def render_order(order)
    render(:partial => 'effective/orders/order', :locals => {:order => order})
  end

  def render_checkout(order, opts = {})
    raise ArgumentError.new('unable to checkout an order without a user') unless order.user.present?

    locals = {
      :purchased_redirect_url => nil,
      :declined_redirect_url => nil
    }.merge(opts)

    if order.new_record? || !order.valid?
      render(:partial => 'effective/orders/checkout_step_1', :locals => locals.merge({:order => order}))
    else
      render(:partial => 'effective/orders/checkout_step_2', :locals => locals.merge({:order => order}))
    end
  end

  def link_to_my_purchases(opts = {})
    options = {:rel => :nofollow}.merge(opts)
    link_to (options.delete(:label) || 'My Purchases'), effective_orders.my_purchases_path, options
  end
  alias_method :link_to_order_history, :link_to_my_purchases

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

  # Used by the _payment_details partial
  def tableize_order_payment(hash, options = {class: 'table table-bordered'})
    if hash.present? && hash.kind_of?(Hash)
      content_tag(:table, class: options[:class]) do
        title = options.delete(:title)

        content = content_tag(:tbody) do
          hash.map do |k, v|
            content_tag(:tr) do
              content_tag((options[:th] ? :th : :td), k) +
                content_tag(:td) do
                if v.kind_of?(Hash)
                  tableize_order_payment(v, options.merge(th: (options.key?(:sub_th) ? options[:sub_th] : options[:th])))
                elsif v.kind_of?(Array)
                  '[' + v.join(', ') + ']'
                else
                  v
                end
              end
            end
          end.join.html_safe
        end

        title.blank? ? content : (content_tag(:thead) { content_tag(:tr) { content_tag(:th, title, colspan: 2) } } + content)
      end
    else
      hash.to_s.html_safe
    end
  end

end
