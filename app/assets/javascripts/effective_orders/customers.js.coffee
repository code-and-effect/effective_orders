stripeCustomerChangeCardHandler = (key, form) ->
  StripeCheckout.configure
    key: key
    closed: -> EffectiveForm.reset(form) unless form.hasClass('stripe-success')
    token: (token, args) ->
      if token.error
        message = "An error ocurred when contacting Stripe. Your card has not been charged. Your subscription has not changed. Please refresh the page and try again. #{token.error.message}"

        form.removeClass('stripe-success')
        form.find('.effective-orders-customer').find('.invalid-feedback').html(message).show()
        alert(message)
      else
        form.find("input[name$='[stripe_token]']").val('' + token['id'])

        $customer = form.find('.effective-orders-customer')
        $customer.find('.payment-status').html("**** **** **** #{token.card.last4} #{token.card.brand} #{token.card.exp_month}/#{token.card.exp_year}")

        if $customer.data('submit')
          form.addClass('stripe-success').submit()

# When we click 'Change credit card', make sure the form collects a credit card
$(document).on 'click', '.effective-orders-customer .btn-change-card', (event) ->
  event.preventDefault()

  $form = $(event.currentTarget).closest('form')
  stripe = $(event.currentTarget).closest('.effective-orders-customer').data('stripe')

  EffectiveForm.submitting($form)

  stripeCustomerChangeCardHandler(stripe.key, $form).open
    image: stripe.image
    name: stripe.name
    email: stripe.email
    panelLabel: 'Update Card Details'
