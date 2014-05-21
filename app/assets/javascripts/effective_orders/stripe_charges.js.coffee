stripeResponseHandler = (status, response) ->
  if response.error
    $('#effective-orders-ajax-status').html("<i class='icon-exclamation-sign'></i>&nbsp;#{response.error.message}")
    $("input[type='submit']").prop('disabled', false)
  else
    token = response['id']
    form = $('#effective_stripe_charge_form')
    form.find('input#effective_stripe_charge_token').val('' + token)
    form.submit()

indicate_submitting = (form) ->
  form.find("input[type='submit']").prop('disabled', true)
  $('#effective-orders-ajax-status').first().html('<i class="icon-time"></i>&nbsp;Connecting with Stripe to process payment...').show()

$(document).on 'click', "#effective-orders-new-customer-form form input[type='submit']", (event) ->
  event.preventDefault()
  form = $(event.currentTarget).closest('form')

  indicate_submitting(form)

  Stripe.createToken({
    number: form.find('input#effective_stripe_charge_number').val(),
    cvc: form.find('input#effective_stripe_charge_cvc').val(),
    exp_month: form.find('input#effective_stripe_charge_exp_month').val(),
    exp_year: form.find('input#effective_stripe_charge_exp_year').val()
  }, stripeResponseHandler)

  false

$(document).on 'click', "#effective-orders-existing-customer-form form input[type='submit']", (event) ->
  form = $(event.currentTarget).closest('form')
  indicate_submitting(form)
  true

$(document).on 'click', '.enter-new-credit-card', (event) ->
  event.preventDefault()
  $('#effective-orders-existing-customer-form').hide()
  $('#effective-orders-new-customer-form').show()
