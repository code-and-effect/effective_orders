stripeCheckoutHandler = (key, form) ->
  StripeCheckout.configure
    key: key
    token: (token, args) ->
      if token.error
        form.find("input[type='submit']").removeProp('disabled')
        $('input[data-disable-with]').each -> try $.rails.enableFormElement($(this))

        alert("An error ocurred when contacting Stripe.  Your card has not been charged.  Please refresh the page and try again. #{token.error.message}")
      else
        form.find('input#effective_stripe_charge_token').val('' + token['id'])

        form.find("input[type='submit']").prop('disabled', true)
        $('input[data-disable-with]').each -> try $.rails.disableFormElement($(this))

        form.submit()

$(document).on 'click', "#effective-orders-new-charge-form form input[type='submit']", (event) ->
  event.preventDefault()

  obj = $('#effective-orders-new-charge-form')
  form = obj.find('form').first()

  form.find("input[type='submit']").prop('disabled', true)
  $('input[data-disable-with]').each -> try $.rails.disableFormElement($(this))

  stripeCheckoutHandler(obj.data('stripe-publishable-key'), form).open
    name: obj.data('site-title')
    email: obj.data('user-email')
    description: obj.data('description')
    amount: obj.data('amount')
    closed: ->
      form.find("input[type='submit']").removeProp('disabled')
      $('input[data-disable-with]').each -> try $.rails.enableFormElement($(this))
