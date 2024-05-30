// https://developer.deluxe.com/s/article-hosted-payment-form

function initializeDeluxeDelayed() {
  let $deluxe = $('form[data-deluxe-delayed-checkout]:not(.initialized)');
  if($deluxe.length == 0) return;

  let options = $deluxe.data('deluxe-delayed-checkout');

  HostedForm.init(options, {
    onFailure: (data) => { $('#deluxe-delayed-checkout-errors').text(JSON.stringify(data)); },
    onInvalid: (data) => { $('#deluxe-delayed-checkout-errors').text(JSON.stringify(data)); },

    onSuccess: (data) => { 
      let value = btoa(JSON.stringify(data)); // A base64 encoded JSON object

      $form = $('form[data-deluxe-delayed-checkout]').first();
      $form.find('input[name="deluxe_delayed[payment_intent]"]').val(value);
      $form.submit();

      $('#deluxeDelayedCheckout').fadeOut('slow');
      $('#deluxe-delayed-checkout-loading').text('Thank you! Saving card information. Please wait...');
    },
  }).then((instance) => {
    $('#deluxe-delayed-checkout-loading').text('');
    instance.renderHpf();
  });

  $deluxe.addClass('initialized');
};

$(document).ready(function() { initializeDeluxeDelayed() });
$(document).on('turbolinks:load', function() { initializeDeluxeDelayed() });
