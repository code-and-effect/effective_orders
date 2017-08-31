module EffectiveSubscriptionsHelper

  def effective_customer_fields(customer, submit: true)
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

end
