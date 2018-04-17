stripeCheckoutHandler = (key, form) ->
  StripeCheckout.configure
    key: key
    closed: -> EffectiveBootstrap.enable(form) unless form.hasClass('stripe-success')
    token: (token, args) ->
      if token.error
        alert("An error ocurred when contacting Stripe. Your card has not been charged. Please refresh the page and try again. #{token.error.message}")
      else
        form.find("input[name$='[stripe_token]']").val('' + token['id'])
        form.addClass('stripe-success').submit()

$(document).on 'click', "#effective-orders-new-charge-form form [type='submit']", (event) ->
  event.preventDefault()

  obj = $('#effective-orders-new-charge-form')
  $form = obj.find('form').first()
  stripe = obj.data('stripe')

  EffectiveBootstrap.submitting($form)

  stripeCheckoutHandler(stripe.key, $form).open
    image: stripe.image
    name: stripe.name
    description: stripe.description
    email: stripe.email
    amount: stripe.amount
