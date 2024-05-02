// https://developer.deluxe.com/s/article-embedded-payments

function initializeDeluxe() {
  let $deluxe = $('form:not(.initialized)[data-deluxe-checkout]');
  if($deluxe.length == 0) return;

  let jwt = $deluxe.data('deluxe-checkout');
  let options = $deluxe.data('deluxe-options') || {};

  EmbeddedPayments.init(jwt, options).then((instance) => {
    instance
      .setEventHandlers({
        onTxnSuccess: (gateway, data) => {
            console.log(`${gateway} Transaction Succeeded: ${JSON.stringify(data)}`);
        },
        onTxnFailed: (gateway, data) => {
            console.log(`${gateway} Transaction Failed: ${JSON.stringify(data)}`);
        },
        onValidationError: (gateway, errors) => {
            console.log(`Validation Error: ${JSON.stringify(errors)}`);
        },
        onCancel: (gateway) => {
            console.log(`${gateway} transaction cancelled`);
        }
      })
      .render(
        { containerId: "embeddedpayments" }
      );
  });
};

$(document).ready(function() { initializeDeluxe() });
$(document).on('turbolinks:load', function() { initializeDeluxe() });
