stripeCheckoutHandler = (key, form) ->
  StripeCheckout.configure
    key: key
    closed: ->
      form.find("input[type='submit']").removeAttr('disabled')
      $('input[data-disable-with]').each -> try $.rails.enableFormElement($(this))
    token: (token, args) ->
      if token.error
        form.find("input[type='submit']").removeAttr('disabled')
        $('input[data-disable-with]').each -> try $.rails.enableFormElement($(this))

        alert("An error ocurred when contacting Stripe. Your card has not been charged. Please refresh the page and try again. #{token.error.message}")
      else
        form.find("input[name$='[stripe_token]']").val('' + token['id'])

        form.find("input[type='submit']").prop('disabled', true)
        $('input[data-disable-with]').each -> try $.rails.disableFormElement($(this))
        form.submit()

$(document).on 'click', "#effective-orders-new-charge-form form input[type='submit']", (event) ->
  event.preventDefault()

  obj = $('#effective-orders-new-charge-form')
  $form = obj.find('form').first()
  stripe = obj.data('stripe')

  # Disable the form
  $form.find("input[type='submit']").prop('disabled', true)
  $('input[data-disable-with]').each -> try $.rails.disableFormElement($(this))

  stripeCheckoutHandler(stripe.key, $form).open
    image: stripe.image
    name: stripe.name
    description: stripe.description
    email: stripe.email
    amount: stripe.amount
