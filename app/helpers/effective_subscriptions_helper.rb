module EffectiveSubscriptionsHelper

  def effective_customer_fields(form, submit: true)
    raise 'expected an Effective::FormBuilder object' unless form.class.name == 'Effective::FormBuilder'
    raise 'form object must be an Effective::Subscripter object' unless form.object.class.name == 'Effective::Subscripter'

    render(
      partial: 'effective/customers/fields',
      locals: {
        f: form,
        submit: submit,
        stripe: {
          email: form.object.customer.user.email,
          image: stripe_site_image_url,
          key: EffectiveOrders.stripe[:publishable_key],
          name: EffectiveOrders.stripe[:site_title],
        }
      }
    )
  end

  def stripe_plans_collection(form)
    raise 'expected an Effective::FormBuilder object' unless form.class.name == 'Effective::FormBuilder'
    raise 'form object must be a subscripter object' unless form.object.class.name == 'Effective::Subscripter'

    plans = EffectiveOrders.stripe_plans.values.sort do |x, y|
      amount = (x[:amount] <=> y[:amount])
      (amount != 0) ? amount : x[:name] <=> y[:name]
    end

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
