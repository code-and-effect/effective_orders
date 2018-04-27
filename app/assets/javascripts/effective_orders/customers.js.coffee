stripeCustomerChangeCardHandler = (key, form) ->
  StripeCheckout.configure
    key: key
    closed: -> EffectiveForm.reset(form) unless form.hasClass('stripe-success')
    token: (token, args) ->
      if token.error
        message = "An error ocurred when contacting Stripe. Your card has not been charged. Please refresh the page and try again. #{token.error.message}"

        form.removeClass('stripe-success')
        form.find('.invalid-feedback').html(message).show()
        alert(message)
      else
        form.find("input[name$='[stripe_token]']").val('' + token['id'])
        form.addClass('stripe-success').submit() # Submits the form. As this is a remote form, submits via JS

# When we click 'Change credit card', make sure the form collects a credit card
$(document).on 'click', ".effective-orders-stripe-update-card[type='submit']", (event) ->
  $form = $(event.currentTarget).closest('form')

  # Get stripe data payload
  stripe = $form.data('stripe')
  return unless stripe?

  # Okay, we're good to call stripe
  event.preventDefault()
  EffectiveForm.submitting($form) # Disable and spin while we popup stripe

  stripeCustomerChangeCardHandler(stripe.key, $form).open
    image: stripe.image
    name: stripe.name
    email: stripe.email
    panelLabel: 'Update Card Details'
