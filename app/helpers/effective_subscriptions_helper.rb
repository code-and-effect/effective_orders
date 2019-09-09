module EffectiveSubscriptionsHelper

  def subscripter_stripe_data(subscripter)
    {
      email: current_user.email,
      image: stripe_site_image_url,
      key: EffectiveOrders.stripe[:publishable_key],
      name: EffectiveOrders.stripe[:site_title],
    }
  end

  def subscripter_stripe_plans(subscripter)
    EffectiveOrders.stripe_plans
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



end
