module EffectivePaypalHelper
  class ConfigReader
    def self.cert_or_key(config)
      if File.exist?(EffectiveOrders.paypal[config])
        File.read(EffectiveOrders.paypal[config]) rescue {}
      else
        EffectiveOrders.paypal[config] || {}
      end
    end
  end

  # These're constants so they only get read once, not every order request
  PAYPAL_CERT_PEM = ConfigReader.cert_or_key(:paypal_cert)
  APP_CERT_PEM    = ConfigReader.cert_or_key(:app_cert)
  APP_KEY_PEM     = ConfigReader.cert_or_key(:app_key)

  def paypal_encrypted_payload(order)
    raise "unable to read EffectiveOrders PayPal paypal_cert #{EffectiveOrders.paypal[:paypal_cert]}" unless PAYPAL_CERT_PEM.present?
    raise "unable to read EffectiveOrders PayPal app_cert #{EffectiveOrders.paypal[:app_cert]}" unless APP_CERT_PEM.present?
    raise "unable to read EffectiveOrders PayPal app_key #{EffectiveOrders.paypal[:app_key]}" unless APP_KEY_PEM.present?

    values = {
      business: EffectiveOrders.paypal[:seller_email],
      custom: EffectiveOrders.paypal[:secret],
      cmd: '_cart',
      upload: 1,
      return: effective_orders.order_purchased_url(order),
      notify_url: effective_orders.paypal_postback_url,
      cert_id: EffectiveOrders.paypal[:cert_id],
      currency_code: EffectiveOrders.paypal[:currency],
      invoice: order.id,
      amount: (order.subtotal / 100.0).round(2),
      tax_cart: (order.tax / 100.0).round(2)
    }

    order.order_items.each_with_index do |item, x|
      values["item_number_#{x+1}"] = x+1
      values["item_name_#{x+1}"] = item.title
      values["quantity_#{x+1}"] = item.quantity
      values["amount_#{x+1}"] = '%.2f' % (item.price / 100.0)
      values["tax_#{x+1}"] = '%.2f' % ((item.tax / 100.0) / item.quantity)  # Tax for 1 of these items
    end

    signed = OpenSSL::PKCS7::sign(OpenSSL::X509::Certificate.new(APP_CERT_PEM), OpenSSL::PKey::RSA.new(APP_KEY_PEM, ''), values.map { |k, v| "#{k}=#{v}" }.join("\n"), [], OpenSSL::PKCS7::BINARY)
    OpenSSL::PKCS7::encrypt([OpenSSL::X509::Certificate.new(PAYPAL_CERT_PEM)], signed.to_der, OpenSSL::Cipher::Cipher::new("DES3"), OpenSSL::PKCS7::BINARY).to_s.gsub("\n", "")
  end
end
