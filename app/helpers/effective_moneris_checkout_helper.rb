module EffectiveMonerisCheckoutHelper
  SCRUB = /[^\w\d#,\s]/

  def moneris_checkout_preload_request(order)
    # Make the Preload Request
    params = {
      # Required
      environment: EffectiveOrders.moneris_checkout.fetch(:environment),

      api_token: EffectiveOrders.moneris_checkout.fetch(:api_token),
      store_id: EffectiveOrders.moneris_checkout.fetch(:store_id),
      checkout_id: EffectiveOrders.moneris_checkout.fetch(:checkout_id),

      action: :preload,
      txn_total: '%.2f' % (order.total_with_surcharge / 100.0)

      # Optional
      order_no: order.transaction_id, # Has to be unique. This is order number, billing name and Time.now
      cust_id: order.user_id,
      language: 'en',

      contact_details: {
        first_name: moneris_checkout_scrub(order.billing_first_name),
        last_name: moneris_checkout_scrub(order.billing_last_name),
        email: order.email,
      }
    }

    if (address = order.billing_address).present?
      params.merge!(
        billing_details: {
          address_1: moneris_checkout_scrub(address.address1),
          address_2: moneris_checkout_scrub(address.address2),
          city: moneris_checkout_scrub(address.city),
          province: address.state_code,
          country: address.country_code,
          postal_code: address.postal_code
        }
      )
    end

    if (address = order.shipping_address).present?
      params.merge!(
        shipping_details: {
          address_1: moneris_checkout_scrub(address.address1),
          address_2: moneris_checkout_scrub(address.address2),
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

  def moneris_checkout_scrub(value)
    return value unless value.kind_of?(String)
    value.gsub(SCRUB, '').first(50)
  end

end
