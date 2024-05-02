module EffectiveDeluxeHelper
  SCRUB = /[^\w\d#,\s]/

  def deluxe_jwt(order)
    payload = deluxe_payload(order)
    shared_secret = EffectiveOrders.deluxe.fetch(:client_secret)

    JWT.encode(payload, shared_secret, 'HS256')
  end

  def deluxe_options(order)
    {
      countryCode: "CA",
      currencyCode: EffectiveOrders.deluxe.fetch(:currency).upcase,
      merchantCapabilities: ["supports3DS"],
      allowedCardAuthMethods: ["PAN_ONLY", "CRYPTOGRAM_3DS"],
      supportedNetworks: ["visa", "masterCard", "amex", "discover"],
      googlePayEnv: "TEST",
    }
  end

  def deluxe_payload(order)
    attributes = {
      accessToken: EffectiveOrders.deluxe.fetch(:access_token),
      amount: ('%.2f' % (order.total_with_surcharge / 100.0)),
      processingFee: 1.00,
      transactionReference: order.transaction_id,
      currency: EffectiveOrders.deluxe.fetch(:currency).upcase,
      hideproductspanel: false,
      hidepaybutton: false,
      hideaddresspanel: false,
      hidecancelbutton: false,
      hidetermsandconditions: false,
      hidesummarypanel: false,
      hidetotals: false
    }

    customer = {
      firstName: checkout_scrub(order.billing_first_name),
      lastName: checkout_scrub(order.billing_last_name),
      email: order.email
    }

    if (address = order.billing_address).present?
      customer.merge!(
        billingAddress: {
          address: checkout_scrub(address.address1),
          city: checkout_scrub(address.city),
          state: address.state_code,
          zipCode: address.postal_code,
          countryCode: address.country_code,
        }
      )
    end

    if (address = order.shipping_address).present?
      customer.merge!(
        shippingAddress: {
          address: checkout_scrub(address.address1),
          city: checkout_scrub(address.city),
          state: address.state_code,
          zipCode: address.postal_code,
          countryCode: address.country_code
        }
      )
    end

    # Products
    products = order.order_items.map do |order_item|
      { 
        name: order_item.to_s, 
        amount: order_item.price, 
        quantity: order_item.quantity 
        # imageurl: '',
        # attributes: []
      }
    end
      
    payload = attributes.merge(customer: customer).merge(products: products)

    # A JSON of everything
    payload
  end

  def checkout_scrub(value)
    return value unless value.kind_of?(String)
    value.gsub(SCRUB, '')
  end
end
