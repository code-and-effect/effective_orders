module EffectiveSubscriptionsHelper

  def effective_customer_fields(form, submit: true)
    raise 'expected a SimpleForm::FormBuilder object' unless form.class.name == 'SimpleForm::FormBuilder'
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

  def stripe_plans_collection(form, include_trial: nil, selected_class: 'selected panel-primary')
    raise 'expected a SimpleForm::FormBuilder object' unless form.class.name == 'SimpleForm::FormBuilder'
    raise 'form object must be an acts_as_subscribable object' unless form.object.subscribable.subscripter.present?

    include_trial = form.object.subscribable.subscribed?('trial') if include_trial.nil?

    plans = include_trial ? EffectiveOrders.stripe_plans : EffectiveOrders.stripe_plans.except('trial')
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

  def effective_subscription_fields(form, label: false, required: true, include_trial: nil, item_wrapper_class: 'col-sm-6 col-md-4 col-lg-3', selected_class: 'selected panel-primary', wrapper_class: 'row')
    raise 'expected a SimpleForm::FormBuilder object' unless form.class.name == 'SimpleForm::FormBuilder'
    raise 'form object must be an acts_as_subscribable object' unless form.object.subscripter.present?

    render(
      partial: 'effective/subscriptions/fields',
      locals: {
        form: form,
        label: label,
        required: required,
        include_trial: include_trial,
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

end
