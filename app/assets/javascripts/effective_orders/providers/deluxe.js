// https://developer.deluxe.com/s/article-hosted-payment-form

function initializeDeluxe() {
  let $deluxe = $('form[data-deluxe-checkout]:not(.initialized)');
  if($deluxe.length == 0) return;

  let options = $deluxe.data('deluxe-checkout');

  HostedForm.init(options, {
    onFailure: (data) => { $('#deluxe-checkout-errors').text(JSON.stringify(data)); },
    onInvalid: (data) => { $('#deluxe-checkout-errors').text(JSON.stringify(data)); },

    onSuccess: (data) => { 
      let value = btoa(JSON.stringify(data)); // A base64 encoded JSON object

      $form = $('form[data-deluxe-checkout]').first();
      $form.find('input[name="deluxe[payment_intent]"]').val(value);
      $form.submit();
    },
  }).then((instance) => {
    $('#deluxe-checkout-loading').remove();
    instance.renderHpf();
  });

  $deluxe.addClass('initialized');
};

$(document).ready(function() { initializeDeluxe() });
$(document).on('turbolinks:load', function() { initializeDeluxe() });
