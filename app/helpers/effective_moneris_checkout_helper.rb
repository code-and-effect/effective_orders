module EffectiveMonerisCheckoutHelper

  def moneris_checkout_preload_request(order)
    # Make the Preload Request
    params = {
      # Required
      environment: EffectiveOrders.moneris_checkout.fetch(:environment),

      api_token: EffectiveOrders.moneris_checkout.fetch(:api_token),
      store_id: EffectiveOrders.moneris_checkout.fetch(:store_id),
      checkout_id: EffectiveOrders.moneris_checkout.fetch(:checkout_id),

      action: :preload,
      txn_total: price_to_currency(order.total).gsub(',', '').gsub('$', ''),

      # Optional
      order_no: order.transaction_id, # Has to be unique. This is order number, billing name and Time.now
      cust_id: order.user_id,
      language: 'en',

      contact_details: {
        first_name: order.billing_first_name,
        last_name: order.billing_last_name,
        email: order.email,
      }
    }

    if (address = order.billing_address).present?
      params.merge!(
        billing_details: {
          address_1: address.address1,
          address_2: address.address2,
          city: address.city,
          province: address.state_code,
          country: address.country_code,
          postal_code: address.postal_code
        }
      )
    end

    if (address = order.shipping_address).present?
      params.merge!(
        shipping_details: {
          address_1: address.address1,
          address_2: address.address2,
          city: address.city,
          province: address.state_code,
          country: address.country_code,
          postal_code: address.postal_code
        }
      )
    end

    response = Effective::Http.post(EffectiveOrders.moneris_request_url, params: params)
    preload = response['response'] if response

    raise("moneris preload error #{response}") unless preload && preload['success'].to_s == 'true'

    payload = {
      environment: EffectiveOrders.moneris_checkout.fetch(:environment),
      ticket: preload['ticket']
    }
  end

end
