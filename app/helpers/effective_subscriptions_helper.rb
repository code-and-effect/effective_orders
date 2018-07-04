module EffectiveSubscriptionsHelper

  def stripe_plans_collection(form)
    raise 'expected an Effective::FormBuilder object' unless form.class.name == 'Effective::FormBuilder'

    subscripter = form.object
    raise 'form object must be a subscripter object' unless subscripter.class.name == 'Effective::Subscripter'

    plans = EffectiveOrders.stripe_plans.values.sort do |x, y|
      amount = (x[:amount] <=> y[:amount])
      (amount != 0) ? amount : x[:name] <=> y[:name]
    end

    if (existing = subscripter.customer.stripe_subscription_interval).present?
      plans.select! { |plan| plan[:interval] == existing }
    end

    plans.map do |plan|
      partial = (
        if lookup_context.template_exists?("effective/subscriptions/#{plan[:id].downcase}", [], true)
          "effective/subscriptions/#{plan[:id].downcase}" # Render the app's views/effective/subscriptions/_gold.html.haml
        elsif lookup_context.template_exists?("effective/subscriptions/#{plan[:name].downcase}", [], true)
          "effective/subscriptions/#{plan[:name].downcase}" # Render the app's views/effective/subscriptions/_gold.html.haml
        else
          'effective/subscriptions/plan' # Render effective_orders default plan panel
        end
      )

      content = render(partial: partial, locals: {
        f: form,
        plan: plan,
        selected: Array(form.object.stripe_plan_id).include?(plan[:id]),
        subscribable: form.object.subscribable,
        subscribed: form.object.subscribable.subscribed?(plan[:id])
      })

      [content, plan[:id]]
    end
  end

  def subscribable_form_with(subscribable)
    raise 'form object must be an acts_as_subscribable object' unless subscribable.respond_to?(:subscripter)

    subscripter = subscribable.subscripter
    raise 'subscribable.subscribable_buyer must match current_user' unless subscripter.user == current_user

    render('effective/subscripter/form', subscripter: subscripter)
  end

  def customer_form_with(customer)
    raise 'form object must be an Effective::Customer object' unless customer.kind_of?(Effective::Customer)
    raise 'expected customer user to match current user' if customer.user != current_user

    subscripter = Effective::Subscripter.new(customer: customer, user: customer.user)

    render('effective/customers/form', subscripter: subscripter)
  end

  def subscripter_stripe_data(subscripter)
    {
      email: current_user.email,
      image: stripe_site_image_url,
      key: EffectiveOrders.stripe[:publishable_key],
      name: EffectiveOrders.stripe[:site_title],
      plans: EffectiveOrders.stripe_plans.values
    }
  end

end
