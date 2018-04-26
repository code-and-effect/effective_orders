stripeSubscriptionHandler = (key, form) ->
  StripeCheckout.configure
    key: key
    closed: -> EffectiveForm.reset(form) unless form.hasClass('stripe-success')
    token: (token, args) ->
      if token.error
        message = "An error ocurred when contacting Stripe. Your card has not been charged. Your subscription has not changed. Please refresh the page and try again. #{token.error.message}"

        form.removeClass('stripe-success')
        form.find('.effective-orders-stripe-plans').find('.invalid-feedback').html(message).show()
        alert(message)
      else
        form.find("input[name='effective_subscripter[stripe_token]']").val('' + token['id'])
        form.addClass('stripe-success').submit()

# When I submit a for that needs a subscripter token, do the stripe thing.
$(document).on 'click', ".effective-orders-subscripter-token-required[type='submit']", (event) ->
  event.preventDefault()
  $form = $(event.currentTarget).closest('form')

  # Get the stripe data
  $plans = $form.find('.effective-orders-stripe-plans').first()
  selected_plan_id = $plans.find("input[name='effective_subscripter[stripe_plan_id]']:checked").val()
  return unless $plans.length > 0 && selected_plan_id.length > 0

  EffectiveForm.submitting($form)

  stripe = $plans.data('stripe')
  plan = stripe.plans.find (plan, _) => plan.id == selected_plan_id

  stripeSubscriptionHandler(stripe.key, $form).open
    image: stripe.image
    name: stripe.name
    description: plan.name
    email: stripe.email
    amount: plan.amount
    panelLabel: "{{amount}}#{plan.occurrence} Go!"

# When I click on a stripe plan ID radio button, add .effective-orders-subscripter-token-required to the form if required
$(document).on 'change', "input[name='effective_subscripter[stripe_plan_id]']", (event) ->
  $plan = $(event.currentTarget)
  return unless $plan.is(':checked')

  selected_plan_id = $plan.val()

  $plans = $plan.closest('.effective-orders-stripe-plans').first()
  plan = $plans.data('stripe').plans.find (plan, _) => plan.id == selected_plan_id

  token_required = $plans.data('stripe').token_required

  if (plan.amount || 0) > 0 && token_required
    console.log 'token required'
    $plans.closest('form').find("input[type='submit'],button[type='submit']").addClass('effective-orders-subscripter-token-required')
  else
    console.log 'token not required'
    $plans.closest('form').find("input[type='submit'],button[type='submit']").removeClass('effective-orders-subscripter-token-required')

  true
