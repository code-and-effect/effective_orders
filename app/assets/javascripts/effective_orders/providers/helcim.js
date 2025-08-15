// https://devdocs.helcim.com/docs/render-helcimpayjs

$(document).on('click', 'form[data-helcim-checkout] a', function(event) {
  event.preventDefault();
  initializeHelcim();
});

function initializeHelcim() {
  let $helcim = $('form[data-helcim-checkout]');
  if($helcim.length == 0) return;

  let token = $helcim.data('helcim-checkout');

  // From HelcimPay.js
  appendHelcimPayIframe(token)

  // Add our event listener
  window.addEventListener('message', helcimPayIframeEvent, false);
};

function helcimPayIframeEvent(event) {
  if(event.data.eventName.startsWith('helcim-pay-js')) {

    if(event.data.eventStatus == 'HIDE') {
      window.removeEventListener('message', helcimPayIframeEvent, false);

      let button = $('.effective-helcim-checkout').find('#helcim-checkout-button').get(0);
      Rails.enableElement(button)
    }

    if(event.data.eventStatus == 'SUCCESS') {
      window.removeEventListener('message', helcimPayIframeEvent, false);

      let payment = btoa(event.data.eventMessage);
  
      let $form = $('form[data-helcim-checkout]').first();
      $form.find('input[name="helcim[payment]"]').val(payment);
      $form.submit();
  
      $('#helcimCheckout').fadeOut('slow');
      $('#helcim-checkout-loading').text('Thank you! Processing payment information. Please wait...');
    }
  }
};
