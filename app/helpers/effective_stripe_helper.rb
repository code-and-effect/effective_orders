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
    intent = Stripe::PaymentIntent.create({
      amount: order.total,
      currency: EffectiveOrders.stripe[:currency],
      metadata: { integration_check: 'accept_a_payment'}
    })

    payload = {
      client_secret: intent.client_secret,
      name: EffectiveOrders.stripe[:site_title],
      image: stripe_site_image_url,
      email: order.user.email,
      key: EffectiveOrders.stripe[:publishable_key],
      payment_required: true # Mine
    }

    payload.to_json
  end

end
