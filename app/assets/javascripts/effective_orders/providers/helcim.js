// https://devdocs.helcim.com/docs/render-helcimpayjs

function initializeHelcim() {
  let $helcim = $('form[data-helcim-checkout]:not(.initialized)');
  if($helcim.length == 0) return;

  let token = $helcim.data('helcim-checkout');
  attachHelcimPayIframe(token);

  $helcim.addClass('initialized');
};

function attachHelcimPayIframe(token, csrf='') {
  if(token === null || token === 'undefined' || token.length !== 22) {
    console.error('Invalid checkout token.');
    return;
  }

  const url = `https://secure.helcim.app/helcim-pay/${token}`;
  const iFrame = document.createElement('iframe');

  iFrame.name = csrf;
  iFrame.id = 'helcimPayIframe';
  iFrame.src = url;
  iFrame.width = '100%';
  iFrame.height = '1000px';
  iFrame.frameBorder = '0';
  iFrame.scrolling = 'no';
  iFrame.allow = 'payment';

  window.addEventListener('message', helcimPayIframeEvent, false);

  $('#helcimCheckout').append(iFrame);
}

function helcimPayIframeEvent(event) {
  if(event.data.eventName == 'helcim-pay-initialized') {
    $('#helcim-checkout-loading').text('');
  };

  if(event.data.eventName.startsWith('helcim-pay-js') && event.data.eventStatus == 'SUCCESS') {
    window.removeEventListener('message', helcimPayIframeEvent, false);

    let payment = btoa(event.data.eventMessage);

    let $form = $('form[data-helcim-checkout]').first();
    $form.find('input[name="helcim[payment]"]').val(payment);
    $form.submit();

    $('#helcimCheckout').fadeOut('slow');
    $('#helcim-checkout-loading').text('Thank you! Processing payment information. Please wait...');
  };
}

$(document).ready(function() { initializeHelcim() });
$(document).on('turbolinks:load', function() { initializeHelcim() });
