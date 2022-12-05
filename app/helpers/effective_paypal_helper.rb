module EffectivePaypalHelper
  class ConfigReader
    def self.cert_or_key(config)
      if File.exist?(EffectiveOrders.paypal[config])
        (File.read(EffectiveOrders.paypal[config]) rescue nil)
      else
        EffectiveOrders.paypal[config]
      end
    end
  end

  # These're constants so they only get read once, not every order request
  if EffectiveOrders.paypal?
    PAYPAL_CERT_PEM = ConfigReader.cert_or_key(:paypal_cert)
    APP_CERT_PEM    = ConfigReader.cert_or_key(:app_cert)
    APP_KEY_PEM     = ConfigReader.cert_or_key(:app_key)
  end

  def paypal_encrypted_payload(order)
    raise 'required paypal paypal_cert is missing' unless PAYPAL_CERT_PEM.present?
    raise 'required paypal app_cert is missing' unless APP_CERT_PEM.present?
    raise 'required paypal app_key is missing' unless APP_KEY_PEM.present?

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
      amount: '%.2f' % (order.amount_owing / 100.0),
      tax_cart: '%.2f' % ((order.tax + order.surcharge_tax) / 100.0)
    }

    number = 0

    order.order_items.each do |item|
      number += 1

      values["item_number_#{number}"] = number
      values["item_name_#{number}"] = item.name
      values["quantity_#{number}"] = item.quantity
      values["amount_#{number}"] = '%.2f' % (item.price / 100.0)
      values["tax_#{number}"] = '%.2f' % ((item.tax / 100.0) / item.quantity)  # Tax for 1 of these items
    end

    # Credit Card Surcharge
    if order.surcharge != 0
      number += 1

      values["item_number_#{number}"] = number
      values["item_name_#{number}"] = 'Credit Card Surcharge'
      values["quantity_#{number}"] = 1
      values["amount_#{number}"] = '%.2f' % (order.surcharge / 100.0)
      values["tax_#{number}"] = '%.2f' % (order.surcharge_tax / 100.0)
    end

    signed = OpenSSL::PKCS7::sign(OpenSSL::X509::Certificate.new(APP_CERT_PEM), OpenSSL::PKey::RSA.new(APP_KEY_PEM, ''), values.map { |k, v| "#{k}=#{v}" }.join("\n"), [], OpenSSL::PKCS7::BINARY)
    OpenSSL::PKCS7::encrypt([OpenSSL::X509::Certificate.new(PAYPAL_CERT_PEM)], signed.to_der, OpenSSL::Cipher::Cipher::new("DES3"), OpenSSL::PKCS7::BINARY).to_s.gsub("\n", "")
  end
end
