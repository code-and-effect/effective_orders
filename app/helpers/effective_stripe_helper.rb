module EffectiveStripeHelper

  def stripe_plan_description(obj)
    plan = (
      case obj
      when Hash            ; obj
      when ::Stripe::Plan  ; EffectiveOrders.stripe_plans.find { |plan| plan[:id] == obj.id }
      else                 ; raise 'unexpected object'
      end
    )

    raise("unknown stripe plan: #{obj}") unless plan.kind_of?(Hash) && plan[:id].present?

    plan[:description]
  end

  def stripe_invoice_line_description(line, simple: false)
    [
      "#{line.quantity}x",
      line.plan.name,
      price_to_currency(line.amount),
      ("#{Time.zone.at(line.period.start).strftime('%F')}" unless simple),
      ('to' unless simple),
      ("#{Time.zone.at(line.period.end).strftime('%F')}" unless simple),
      line.description.presence
    ].compact.join(' ')
  end

  def stripe_coupon_description(coupon)
    amount = coupon.amount_off.present? ? price_to_currency(coupon.amount_off) : "#{coupon.percent_off}%"

    if coupon.duration_in_months.present?
      "#{coupon.id} - #{amount} off for #{coupon.duration_in_months} months"
    else
      "#{coupon.id} - #{amount} off #{coupon.duration}"
    end
  end

  def stripe_site_image_url
    return nil unless EffectiveOrders.stripe? && (url = EffectiveOrders.stripe[:site_image].to_s).present?
    url.start_with?('http') ? url : asset_url(url)
  end

  def stripe_order_description(order)
    "#{order.num_items} items (#{price_to_currency(order.total)})"
  end

  def stripe_payment_intent(order)
    customer = Effective::Customer.for_user(order.user)

    begin
      stripe_payment_intent_payload(order, customer)
    rescue => e
      raise unless Rails.env.development?
      stripe_payment_intent_payload(order, Effective::Customer.new(user: order.user))
    end
  end

  def stripe_payment_intent_payload(order, customer)
    customer.create_stripe_customer! # Only creates if customer not already present

    payment = {
      amount: order.total,
      currency: EffectiveOrders.stripe[:currency],
      customer: customer.stripe_customer_id,
      payment_method: customer.payment_method_id.presence,
      description: stripe_order_description(order),
      metadata: { order_id: order.id },
    }

    token_required = customer.token_required?

    intent = begin
      Rails.logger.info "[STRIPE] create payment intent : #{payment}"
      Stripe::PaymentIntent.create(payment)
    rescue Stripe::CardError => e
      token_required = true
      Rails.logger.info "[STRIPE] (error) get payment intent : #{e.error.payment_intent.id}"
      Stripe::PaymentIntent.retrieve(e.error.payment_intent.id)
    end

    payload = {
      key: EffectiveOrders.stripe[:publishable_key],
      client_secret: intent.client_secret,
      payment_method: intent.payment_method,

      active_card: customer.active_card,
      email: customer.email,
      token_required: token_required
    }

    payload
  end

end
