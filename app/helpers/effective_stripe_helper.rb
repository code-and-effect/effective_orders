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
    rescue Exception => e
      raise unless Rails.env.development?
      stripe_payment_intent_payload(order, Effective::Customer.new(user: order.user))
    end
  end

  def stripe_payment_intent_payload(order, customer)
    customer.create_stripe_customer! # Only creates if customer not already present

    remember_card = EffectiveOrders.stripe[:remember_card]
    token_required = customer.token_required?

    payment = {
      amount: order.total_with_surcharge,
      currency: EffectiveOrders.stripe[:currency],
      customer: customer.stripe_customer_id,
      description: stripe_order_description(order),
      metadata: { order_id: order.id }
    }

    if remember_card && customer.payment_method_id.present?
      payment[:payment_method] = customer.payment_method_id
    end

    # Always prompt them for a card unless remember card
    token_required = true unless remember_card

    intent = begin
      Rails.logger.info "[STRIPE] create payment intent : #{payment}"
      EffectiveOrders.with_stripe { ::Stripe::PaymentIntent.create(payment) }
    rescue Stripe::CardError => e
      token_required = true
      Rails.logger.info "[STRIPE] (error) get payment intent : #{e.error.payment_intent.id}"
      EffectiveOrders.with_stripe { ::Stripe::PaymentIntent.retrieve(e.error.payment_intent.id) }
    end

    payload = {
      key: EffectiveOrders.stripe[:publishable_key],
      client_secret: intent.client_secret,
      email: customer.email,
      token_required: token_required
    }

    if remember_card && customer.active_card.present? && intent.payment_method.present?
      payload[:active_card] = customer.active_card
    end

    if intent.payment_method.present?
      payload[:payment_method] = intent.payment_method
    end

    payload
  end

end
