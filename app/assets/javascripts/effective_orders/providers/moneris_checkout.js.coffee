this.MonerisCheckoutForm ||= class MonerisCheckoutForm
  constructor: ->
    @form = null
    @data = null
    @moneris = null

  initialize: ->
    @form = $('form[data-moneris-checkout-form]:not(.initialized)').first()
    return false unless @form.length > 0

    @data = @form.data('moneris-checkout-form')
    @moneris = new monerisCheckout()

    @mount()
    @form.addClass('initialized')

  mount: ->
    @moneris.setCheckoutDiv('monerisCheckout')

    @moneris.setCallback('page_loaded', @pageLoaded)
    @moneris.setCallback('cancel_transaction', @cancelTransaction)
    @moneris.setCallback('error_event', @errorEvent)
    @moneris.setCallback('payment_receipt', @paymentReceipt)
    @moneris.setCallback('payment_complete', @paymentComplete)

    @moneris.setMode(@data.environment)
    @moneris.startCheckout(@data.ticket)

  success: (payload) ->
    @moneris.closeCheckout()

    payment = JSON.parse(payload)
    @form.find('#moneris-checkout-success').html("Transaction complete! Please wait a moment...")
    @form.find("input[name$='[ticket]']").first().val(payment['ticket'])
    @form.submit()

  error: (text) ->
    @moneris.closeCheckout()

    text = "<p>" + text + "<p>Please <a href='#', onclick='window.location.reload();' class='alert-link'>reload the page</a> and try again.</p>"
    @form.find('#moneris-checkout-error').addClass('alert').html(text)
    EffectiveForm.invalidate(@form)

  # Moneris iframe has loaded
  pageLoaded: (payload) =>
    preload = JSON.parse(payload)

    switch preload['response_code']
      when '001'
        true # Success. Nothing to do.
      when '902'
        @error('3-D secure failed on response')
      when '2001'
        @error('Invalid ticket/ticket re-use')
      else
        @error('Unknown payment gateway preload status')

  # Cancel Button
  cancelTransaction: (payload) => false

  # Any kind of error
  errorEvent: (payload) =>
    error = JSON.parse(payload)
    @error("A payment gateway error #{error['response_code']} has occurred. Your card has not been charged.")

  # Payment is all done
  paymentReceipt: (payload) => @success(payload)
  paymentComplete: (payload) => @success(payload)

$ -> (new MonerisCheckoutForm()).initialize()
$(document).on 'turbolinks:load', -> (new MonerisCheckoutForm()).initialize()
