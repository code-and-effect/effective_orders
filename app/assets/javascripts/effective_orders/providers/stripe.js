class StripeForm {
  initialize() {
    let $form = $('form[data-stripe-form]').first();
    if ($form.length == 0) { return false; }

    this.$form = $form;
    this.$paymentIntentId = this.$form.find("input[name$='[payment_intent_id]']").first();

    this.data = $form.data('stripe-form');
    this.stripe = Stripe(this.data.key);
    this.card = this.stripe.elements().create("card", { style: this.style() });

    this.mount();
  }

  mount() {
    this.card.mount("#stripe-card-element");

    this.card.addEventListener('change', function ({ error }) {
      if (error) {
        $('#stripe-card-errors').text(error.message);
      } else {
        $('#stripe-card-errors').text('');
      }
    });

    this.$form.on('click', '[type=submit]', (event) => { this.submit(event) });
  }

  shouldUseNewCard() {
    let $newCardForm = this.$form.children('.collapse.show')

    return (
      this.$form.get(0).checkValidity() &&
      (this.data.token_required || $newCardForm.length > 0) &&
      this.$paymentIntentId.val().length == 0
    )
  }

  submit(event) {
    event.preventDefault();

    let payment = this.shouldUseNewCard() ? this.useNewCard() : this.useExistingCard();

    payment.then((result) => {
      if (result.error) {
        this.errorPayment(result.error)
      } else if (result.paymentIntent.status == 'succeeded') {
        this.submitPayment(result.paymentIntent);
      }
    });
  }

  useExistingCard() {
    return this.stripe.confirmCardPayment(this.data.client_secret, {
      payment_method: this.data.payment_method
    });
  }

  useNewCard() {
    return this.stripe.confirmCardPayment(this.data.client_secret, {
      payment_method: {
        card: this.card,
        billing_details: {
          email: this.data.email
        }
      },
      setup_future_usage: 'off_session'
    });
  }

  errorPayment(error) {
    $('#stripe-card-errors').text(error.message);
    EffectiveForm.invalidate(this.$form);
  }

  submitPayment(payment) {
    this.$paymentIntentId.val('' + payment['id']);
    this.$form.submit();
  }

  style() {
    return {
      base: {
        color: "#32325d",
        fontFamily: '"Helvetica Neue", Helvetica, sans-serif',
        fontSmoothing: "antialiased",
        fontSize: "16px",
        "::placeholder": { color: "#aab7c4" }
      },
      invalid: {
        color: "#fa755a",
        iconColor: "#fa755a"
      }
    };
  }
}

$(document).ready(function () { new StripeForm().initialize(); });
