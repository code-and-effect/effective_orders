module EffectiveStripeHelper

  STRIPE_CONNECT_AUTHORIZE_URL = 'https://connect.stripe.com/oauth/authorize'
  STRIPE_CONNECT_TOKEN_URL = 'https://connect.stripe.com/oauth/token'

  def is_stripe_connect_seller?(user)
    Effective::Customer.for_buyer(user).stripe_connect_access_token.present?
  end

  def link_to_new_stripe_connect_customer(opts = {})
    client_id = EffectiveOrders.stripe[:connect_client_id]

    raise 'effective_orders config: stripe.connect_client_id has not been set' unless client_id.present?

    authorize_params = {
      response_type: :code,
      client_id: client_id,            # This is the Application's ClientID
      scope: :read_write,
      state: {
        form_authenticity_token: form_authenticity_token,   # Rails standard CSRF
        redirect_to: URI.encode(request.original_url)  # TODO: Allow this to be customized
      }.to_json
    }

    # Add the stripe_user parameter if it's possible
    stripe_user_params = opts.delete :stripe_user
    authorize_params.merge!({stripe_user: stripe_user_params}) if stripe_user_params.is_a?(Hash)

    authorize_url = STRIPE_CONNECT_AUTHORIZE_URL + '?' + authorize_params.to_query
    options = {}.merge(opts)
    link_to image_tag('/assets/effective_orders/stripe_connect.png'), authorize_url, options
  end

  ### Subscriptions Helpers
  def effective_subscription_fields(form, label: false, required: true, include_blank: nil, item_wrapper_class: 'col-sm-6 col-md-4 col-lg-3', selected_class: 'selected panel-primary', wrapper_class: 'row')
    raise 'expected a SimpleForm::FormBuilder object' unless form.class.name == 'SimpleForm::FormBuilder'
    raise 'form object must be an acts_as_subscribable object' unless form.object.subscripter.present?

    render(
      partial: 'effective/subscriptions/fields',
      locals: {
        form: form,
        label: label,
        required: required,
        include_blank: include_blank,
        item_wrapper_class: item_wrapper_class,
        selected_class: selected_class,
        stripe: {
          email: form.object.buyer.email,
          image: stripe_site_image_url,
          key: EffectiveOrders.stripe[:publishable_key],
          name: EffectiveOrders.stripe[:site_title],
          plans: EffectiveOrders.stripe_plans.values,
          token_required: form.object.subscripter.token_required?
        },
        wrapper_class: wrapper_class
      }
    )
  end

  def stripe_plans_collection(form, include_blank: nil, selected_class: 'selected panel-primary')
    raise 'expected a SimpleForm::FormBuilder object' unless form.class.name == 'SimpleForm::FormBuilder'
    raise 'form object must be an acts_as_subscribable object' unless form.object.subscribable.subscripter.present?

    include_blank = form.object.subscribable.subscribed?('blank') if include_blank.nil?

    plans = include_blank ? EffectiveOrders.stripe_plans : EffectiveOrders.stripe_plans.except('blank')
    plans = plans.values.sort { |x, y| (amount = x[:amount] <=> y[:amount]) != 0 ? amount : x[:name] <=> y[:name] }

    plans.map do |plan|
      partial = (
        if lookup_context.template_exists?("effective/subscriptions/#{plan[:id].downcase}", [], true)
          "effective/subscriptions/#{plan[:id].downcase}" # Render the app's views/effective/subscriptions/_gold.html.haml
        else
          'effective/subscriptions/plan' # Render effective_orders default plan panel
        end
      )

      content = render(partial: partial, locals: {
        f: form,
        plan: plan,
        selected: Array(form.object.stripe_plan_id).include?(plan[:id]),
        selected_class: selected_class,
        subscribable: form.object.subscribable,
        subscribed: form.object.subscribable.subscribed?(plan[:id])
      })

      [content, plan[:id]]
    end
  end

  def effective_customer_fields(customer, submit: false)
    raise 'expected an Effective::Customer object' unless customer.class.name == 'Effective::Customer'

    render(
      partial: 'effective/customers/fields',
      locals: {
        customer: customer,
        submit: submit,
        stripe: {
          email: customer.user.email,
          image: stripe_site_image_url,
          key: EffectiveOrders.stripe[:publishable_key],
          name: EffectiveOrders.stripe[:site_title],
        }
      }
    )
  end

  def effective_subscription_fields(form, label: false, required: true, include_blank: nil, item_wrapper_class: 'col-sm-6 col-md-4 col-lg-3', selected_class: 'selected panel-primary', wrapper_class: 'row')
    raise 'expected a SimpleForm::FormBuilder object' unless form.class.name == 'SimpleForm::FormBuilder'
    raise 'form object must be an acts_as_subscribable object' unless form.object.subscripter.present?

    render(
      partial: 'effective/subscriptions/fields',
      locals: {
        form: form,
        label: label,
        required: required,
        include_blank: include_blank,
        item_wrapper_class: item_wrapper_class,
        selected_class: selected_class,
        stripe: {
          email: form.object.buyer.email,
          image: stripe_site_image_url,
          key: EffectiveOrders.stripe[:publishable_key],
          name: EffectiveOrders.stripe[:site_title],
          plans: EffectiveOrders.stripe_plans.values,
          token_required: form.object.subscripter.token_required?
        },
        wrapper_class: wrapper_class
      }
    )
  end

  def stripe_plan_description(obj)
    plan = (
      case obj
      when Hash            ; obj
      when ::Stripe::Plan  ; EffectiveOrders.stripe_plans.find { |plan| plan.id == obj.id }
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
    amount = coupon.amount_off.present? ? ActionController::Base.helpers.price_to_currency(coupon.amount_off) : "#{coupon.percent_off}%"

    if coupon.duration_in_months.present?
      "#{coupon.id} - #{amount} off for #{coupon.duration_in_months} months"
    else
      "#{coupon.id} - #{amount} off #{coupon.duration}"
    end
  end

  def stripe_site_image_url
    return nil unless EffectiveOrders.stripe && (url = EffectiveOrders.stripe[:site_image].to_s).present?
    url.start_with?('http') ? url : asset_url(url)
  end

  def stripe_order_description(order)
    "#{order.num_items} items (#{price_to_currency(order.total)})"
  end

end
