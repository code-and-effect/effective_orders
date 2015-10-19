hideShippingAddressFields = (shipping_address) ->
  shipping_address.hide().find('input, select').prop('required', false)

showShippingAddressFields = (shipping_address) ->
  shipping_address.show().find("input:not([name$='[address2]']),select:not([name$='[state_code]'])").prop('required', true)

initShippingAddressFields = ->
  effective_order = $('.effective-order').first()

  if effective_order.length > 0
    shipping_address_same_as_billing = effective_order.find('#effective_order_shipping_address_same_as_billing')
    shipping_address = effective_order.find('.shipping_address_fields')

    if shipping_address_same_as_billing.length > 0 && shipping_address.length > 0
      if shipping_address_same_as_billing.is(':checked')
        hideShippingAddressFields(shipping_address)
      else
        showShippingAddressFields(shipping_address)

$ -> initShippingAddressFields()
$(document).on 'page:change', -> initShippingAddressFields()

$(document).on 'change', '#effective_order_shipping_address_same_as_billing', (event) ->
  obj = $(event.currentTarget)
  shipping_address = obj.closest('form').find('.shipping_address_fields')

  if obj.is(':checked')
    hideShippingAddressFields(shipping_address)
  else
    showShippingAddressFields(shipping_address)
