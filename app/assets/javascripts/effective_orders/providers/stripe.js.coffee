this.StripeForm ||= class StripeForm
  constructor: ->
    @form = null
    @paymentIntent = null

    @data = null
    @stripe = null
    @card = null

  initialize: ->
    @form = $('form[data-stripe-form]').first()
    return false unless @form.length > 0

    @paymentIntent = @form.find("input[name$='[payment_intent_id]']").first()
    @data = @form.data('stripe-form')
    @stripe = Stripe(@data.key)
    @card = @stripe.elements().create('card', @style())

    @mount()

  style: ->
    style: {
      base: { color: '#32325d', fontSize: '16px', },
      invalid: { color: '#dc3545', iconColor: '#dc3545' }
    }

  mount: ->
    @card.mount('#stripe-card-element')

    @card.addEventListener('change', (error) ->
      $('#stripe-card-errors').text(if error.message then error.message else '')
    )

    @form.on('click', '[type=submit]', (event) => @submit(event))

  submit: (event) ->
    event.preventDefault()

    payment = if @shouldUseNewCard() then @useNewCard() else @useExistingCard()

    $.active = $.active + 1

    payment.then((result) =>
      if result.error
        @errorPayment(result.error)
      else if result.paymentIntent.status == 'succeeded'
        @submitPayment(result.paymentIntent)
    ).then((result) =>
      $.active = $.active - 1
    )

  shouldUseNewCard: ->
    @form.get(0).checkValidity() &&
    @paymentIntent.val().length == 0 &&
    (@data.token_required || @form.children('.collapse.show').length > 0)

  useNewCard: ->
    @stripe.confirmCardPayment(@data.client_secret, {
      payment_method: {
        card: @card,
        billing_details: { email: @data.email }
      },
      setup_future_usage: 'off_session'
    })

  useExistingCard: ->
    @stripe.confirmCardPayment(@data.client_secret, { payment_method: @data.payment_method })

  submitPayment: (payment) ->
    @paymentIntent.val(payment['id'])
    @form.submit()

  errorPayment: (error) ->
    $('#stripe-card-errors').text(error.message)
    EffectiveForm.invalidate(@form);

$ -> (new StripeForm()).initialize()
