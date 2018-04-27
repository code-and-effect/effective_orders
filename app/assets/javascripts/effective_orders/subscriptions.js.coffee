stripeSubscriptionHandler = (key, form) ->
  StripeCheckout.configure
    key: key
    closed: -> EffectiveForm.reset(form) unless form.hasClass('stripe-success')
    token: (token, args) ->
      if token.error
        message = "An error ocurred when contacting Stripe. Your card has not been charged. Your plan has not changed. Please refresh the page and try again. #{token.error.message}"

        form.removeClass('stripe-success')
        form.find('.invalid-feedback').html(message).show()
        alert(message)
      else
        form.find("input[name$='[stripe_token]']").val('' + token['id'])
        form.addClass('stripe-success').submit() # Submits the form. As this is a remote form, submits via JS

# Hijack submit and get a stripe token
$(document).on 'click', ".effective-orders-stripe-token-required[type='submit']", (event) ->
  $form = $(event.currentTarget).closest('form')

  # Get stripe data payload
  stripe = $form.data('stripe')
  return unless stripe?

  # Make sure there is a plan selected
  selected_plan_id = $form.find("input[name$='[stripe_plan_id]']:checked").val() || ''
  return unless selected_plan_id.length > 0

  # Match plan
  plan = stripe.plans.find (plan, _) => plan.id == selected_plan_id
  return unless plan?

  # Okay, we're good to call stripe
  event.preventDefault()
  EffectiveForm.submitting($form) # Disable and spin while we popup stripe

  stripeSubscriptionHandler(stripe.key, $form).open
    image: stripe.image
    name: stripe.name
    email: stripe.email
    description: plan.name
    amount: plan.amount
    panelLabel: "{{amount}}/#{plan.interval} Go!"
