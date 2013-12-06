stripeResponseHandler = (status, response) ->
  console.log "Stripe responded"
  form = $('#effective_stripe_charge_form')

  if response.error
    $('#effective-orders-ajax-status').html("<i class='icon-exclamation-sign'></i>&nbsp;#{response.error.message}")
    $("input[type='submit']").prop('disabled', false)
  else
    token = response['id']
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
    exp_month: form.find('select#effective_stripe_charge_exp_month option:selected').val(),
    exp_year: form.find('select#effective_stripe_charge_exp_year option:selected').val()
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


# // $ ->
# //   methods =
# //     stripeResponseHandler: (status, response) ->
# //       form = $('#stripe-new-card-form')

# //       if response.error
# //         form.find('span.ajax-status').html('<i class="icon-thumbs-down"></i>').show().fadeOut(1000)
# //         form.find('.submit-button').removeAttr('disabled')
# //         form.find('.payment-errors').text(response.error.message)
# //       else
# //         token = response['id']
# //         form.append("<input type='hidden' name='stripeToken' value='" + token + "'/>")
# //         form.get(0).submit()

# //     validate: (form) ->
# //       field = form.find("[name='balance_deposit[amount]']")
# //       if field.val().length == 0
# //         field.parent().find('p.inline-errors').first().remove()
# //         field.parent().append("<p class='inline-errors'>can't be blank</p>")
# //         return false
# //     indicate_submitting: (form) ->
# //       form.find('.submit-button').attr('disabled', 'disabled')
# //       form.find('span.ajax-status').first().html('<i class="icon-time"></i>&nbsp;Processing payment...').show()

# //   $('#content').on 'submit', "#stripe-new-card-form", (event) ->
# //     form = $(event.currentTarget)
# //     if methods.validate(form) == false then return false
# //     methods.indicate_submitting(form)

# //     Stripe.createToken({
# //         number: form.find('.card-number').val(),
# //         cvc: form.find('.card-cvc').val(),
# //         exp_month: form.find('.card-expiry-month').val(),
# //         exp_year: form.find('.card-expiry-year').val()
# //       }, methods.stripeResponseHandler
# //     )
# //     false

# //   $('#content').on 'submit', "#stripe-existing-card-form", (event) ->
# //     form = $(event.currentTarget)
# //     if methods.validate(form) == false then return false
# //     methods.indicate_submitting(form)

# //     true

# //   $('#content').on 'click', '#show-new-credit-card', (event) -> $('#stripe-existing-card-form').hide() ; $('#stripe-new-card-form').show()
# //   $('#content').on 'keydown', "#stripe-new-card-form", (event) -> $(event.currentTarget).find('.payment-errors').html('')

