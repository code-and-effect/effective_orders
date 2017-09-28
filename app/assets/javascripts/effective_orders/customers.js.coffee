stripeCustomerChangeCardHandler = (key, form) ->
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
        form.find("input[name$='[stripe_token]']").val('' + token['id'])

        customer = form.find('.effective-orders-customer')
        customer.find('.active-card').html("**** **** **** #{token.card.last4} #{token.card.brand} #{token.card.exp_month}/#{token.card.exp_year}")

        if customer.data('submit')
          form.find("input[type='submit']").prop('disabled', true)
          $('input[data-disable-with]').each -> try $.rails.disableFormElement($(this))
          form.submit()

# When we click 'Change credit card', make sure the form collects a credit card
$(document).on 'click', '.effective-orders-customer .btn-change-card', (event) ->
  event.preventDefault()

  $form = $(event.currentTarget).closest('form')
  stripe = $(event.currentTarget).closest('.effective-orders-customer').data('stripe')

  # Disable the form
  $form.find("input[type='submit']").prop('disabled', true)
  $('input[data-disable-with]').each -> try $.rails.disableFormElement($(this))

  stripeCustomerChangeCardHandler(stripe.key, $form).open
    image: stripe.image
    name: stripe.name
    email: stripe.email
    panelLabel: 'Update Card Details'
