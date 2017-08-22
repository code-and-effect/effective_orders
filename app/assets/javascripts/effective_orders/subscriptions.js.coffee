stripeSubscriptionHandler = (key, form) ->
  StripeCheckout.configure
    key: key
    closed: ->
      form.find("input[type='submit']").removeAttr('disabled')
      $('input[data-disable-with]').each -> try $.rails.enableFormElement($(this))
    token: (token, args) ->
      if token.error
        form.find("input[type='submit']").removeAttr('disabled')
        $('input[data-disable-with]').each -> try $.rails.enableFormElement($(this))

        alert("An error ocurred when contacting Stripe. Your card has not been charged. Your subscription has not changed. Please refresh the page and try again. #{token.error.message}")
      else
        form.find("input[name$='[subscripter][stripe_token]']").val('' + token['id'])

        form.find("input[type='submit']").prop('disabled', true)
        $('input[data-disable-with]').each -> try $.rails.disableFormElement($(this))

        form.submit()

$(document).on 'click', "input[type='submit'].effective-orders-subscripter-token-required", (event) ->
  event.preventDefault()

  $submit = $(event.currentTarget)
  $form = $submit.closest('form')

  # Disable the form
  $submit.prop('disabled', true)
  $('input[data-disable-with]').each -> try $.rails.disableFormElement($(this))

  # Get the stripe data
  $plans = $form.find('.effective-orders-stripe-plans').first()
  selected_plan_id = $plans.find("input[name$='[subscripter][stripe_plan_id]']:checked").val()

  stripe = $plans.data('stripe')
  plan = stripe.plans.find (plan, _) => plan.id == selected_plan_id

  stripeSubscriptionHandler(stripe.key, $form).open
    image: stripe.image
    name: stripe.name
    description: plan.name
    email: stripe.email
    amount: plan.amount
    panelLabel: "{{amount}}#{plan.occurrence} Go!"

# When a plan is selected, toggle the selected-class on each plan.
# Set the submit button's class if a customer token is required
$(document).on 'change', "input[name$='[subscripter][stripe_plan_id]']", (event) ->
  $plan = $(event.currentTarget)
  return unless $plan.is(':checked')

  $plans = $plan.closest('.effective-orders-stripe-plans').first()
  selected_class = $plans.data('selected-class')
  selected_plan_id = $plan.val()

  $plans.find("input[name$='[subscripter][stripe_plan_id]']").each (_, item) =>
    if $(item).is(':checked')
      $(item).siblings('.panel').addClass(selected_class)
    else
      $(item).siblings('.panel').removeClass(selected_class)

  plan = $plans.data('stripe').plans.find (plan, _) => plan.id == selected_plan_id
  token_required = $plans.data('stripe').token_required

  if (plan.amount || 0) > 0 && token_required
    $plans.closest('form').find("input[type='submit']").addClass('effective-orders-subscripter-token-required')
  else
    $plans.closest('form').find("input[type='submit']").removeClass('effective-orders-subscripter-token-required')

# When the 'Select' button is clicked, set the radio button input
$(document).on 'click', '.effective-orders-stripe-plan .btn-select-plan', (event) ->
  val = $(event.currentTarget).closest('.effective-orders-stripe-plan').find('input:radio').val()
  $(event.currentTarget).closest('.effective-orders-stripe-plans').find('input:radio').val([val]).trigger('change')
  false
