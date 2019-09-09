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

# This updates the form whenever a quantity change is made
$(document).on 'change keyup', '.effective-orders-subscripter-plan-quantity', (event) ->
  $obj = $(event.currentTarget)
  $plan = $obj.closest('.effective-orders-stripe-plan')
  return unless $plan.length == 1

  # Assign the quantity to each quantity field
  $plan.closest('form')
    .find(".effective-orders-stripe-plan:not([data-plan-id='#{$plan.data('id')}'])")
    .find("input[name$='[quantity]']").val($obj.val())

  quantity = $obj.val() || 0

  $plan.closest('form').find(".effective-orders-stripe-plan").each ->
    # Assign all totals
    plan = $(this)
    amount = parseInt(plan.data('amount'))
    interval = plan.data('plan-interval')

    total = (quantity * amount)
    total = (total / 12) if interval == 'year'

    total = '$' + (total / 100.0).toFixed(2)

    plan.find('#effective_subscripter_total_amount').text(total)

    # Assign savings if present
    savings = parseInt(plan.data('savings'))

    if savings > 0
      total_savings = '$' + ((quantity * savings) / 100.0).toFixed(2)
      plan.find('.subscripter-total-savings').find('span').text(total_savings)

# Hijack submit and get a stripe token
$(document).on 'click', ".effective-orders-stripe-token-required[type='submit'],[data-choose-stripe-plan-id]", (event) ->
  $obj = $(event.currentTarget)
  $form = $obj.closest('form')

  # Get stripe data payload
  stripe = $form.data('stripe')
  return unless stripe?

  plans = $form.data('plans')
  return unless plans?

  # If we're doing choose button mode
  if $obj.data('choose-stripe-plan-id')
    $form.find("input[name$='[stripe_plan_id]']").val($obj.data('choose-stripe-plan-id'))
    return true unless $obj.hasClass('effective-orders-stripe-token-required')

  # Make sure there is a plan selected
  selected_plan_id = $form.find("input[name$='[stripe_plan_id]']:checked").val() || $form.find("input[name$='[stripe_plan_id]']").val() || ''
  return unless selected_plan_id.length > 0

  # Match plan
  plan = plans.find (plan, _) => plan.id == selected_plan_id
  return unless plan?

  # Okay, we're good to call stripe
  event.preventDefault()
  EffectiveForm.submitting($form) # Disable and spin while we popup stripe

  stripeSubscriptionHandler(stripe.key, $form).open
    image: stripe.image
    name: stripe.name
    email: stripe.email
    description: plan.name
    panelLabel: 'Update Plan'
