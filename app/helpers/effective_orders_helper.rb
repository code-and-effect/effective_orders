module EffectiveOrdersHelper


  # ======================
  # ======= PayPal =======
  # ======================

  # These're constants so they only get read once, not every order request
  PAYPAL_CERT_PEM = (File.read(EffectiveOrders.paypal[:paypal_cert]) rescue {})
  APP_CERT_PEM = (File.read(EffectiveOrders.paypal[:app_cert]) rescue {})
  APP_KEY_PEM = (File.read(EffectiveOrders.paypal[:app_key]) rescue {})

  def paypal_encrypted_payload(order)
    raise ArgumentError.new("unable to read EffectiveOrders PayPal paypal_cert #{EffectiveOrders.paypal[:paypal_cert]}") unless PAYPAL_CERT_PEM.present?
    raise ArgumentError.new("unable to read EffectiveOrders PayPal app_cert #{EffectiveOrders.paypal[:app_cert]}") unless APP_CERT_PEM.present?
    raise ArgumentError.new("unable to read EffectiveOrders PayPal app_key #{EffectiveOrders.paypal[:app_key]}") unless APP_KEY_PEM.present?

    values = {
      :business => EffectiveOrders.paypal[:seller_email],
      :custom => EffectiveOrders.paypal[:secret],
      :cmd => '_cart',
      :upload => 1,
      :return => effective_orders.order_purchased_url(order),
      :notify_url => effective_orders.paypal_postback_url,
      :cert_id => EffectiveOrders.paypal[:cert_id],
      :currency_code => EffectiveOrders.paypal[:currency],
      :invoice => order.id + EffectiveOrders.paypal[:order_id_nudge].to_i,
      :amount => order.subtotal,
      :tax_cart => order.tax
    }

    order.order_items.each_with_index do |item, x|
      values["item_number_#{x+1}"] = x+1
      values["item_name_#{x+1}"] = item.title
      values["quantity_#{x+1}"] = item.quantity
      values["amount_#{x+1}"] = item.price
      values["tax_#{x+1}"] = '%.2f' % (item.tax / item.quantity)  # Tax for 1 of these items
    end

    signed = OpenSSL::PKCS7::sign(OpenSSL::X509::Certificate.new(APP_CERT_PEM), OpenSSL::PKey::RSA.new(APP_KEY_PEM, ''), values.map { |k, v| "#{k}=#{v}" }.join("\n"), [], OpenSSL::PKCS7::BINARY)
    OpenSSL::PKCS7::encrypt([OpenSSL::X509::Certificate.new(PAYPAL_CERT_PEM)], signed.to_der, OpenSSL::Cipher::Cipher::new("DES3"), OpenSSL::PKCS7::BINARY).to_s.gsub("\n", "")
  end
end
