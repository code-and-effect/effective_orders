# EffectiveOrders Rails Engine

EffectiveOrders.setup do |config|
  # Configure Database Tables
  config.orders_table_name = :orders
  config.order_items_table_name = :order_items
  config.carts_table_name = :carts
  config.cart_items_table_name = :cart_items
  config.customers_table_name = :customers

  # Authorization Method
  config.authorization_method = Proc.new { |controller, action, resource| can?(action, resource) }

  # Require these addresses when creating a new Order.  Works with effective_addresses
  config.require_billing_address = true
  config.require_shipping_address = false

  # For use with development testing, pass the order ID plus this to the processor
  config.order_id_nudge = 0

  # Moneris configuration
  config.moneris_enabled = false

  if Rails.env.production?
    config.moneris = {
      :ps_store_id => '',
      :hpp_key => '',
      :hpp_url => 'https://www3.moneris.com/HPPDP/index.php',
      :verify_url => 'https://www3.moneris.com/HPPDP/verifyTxn.php'
    }
  else
    config.moneris = {
      :ps_store_id => '',
      :hpp_key => '',
      :hpp_url => 'https://esqa.moneris.com/HPPDP/index.php',
      :verify_url => 'https://esqa.moneris.com/HPPDP/verifyTxn.php'
    }
  end

  # Paypal configuration
  config.paypal_enabled = false

  if Rails.env.production?
    config.paypal = {
      :seller_email => '',
      :secret => '',
      :cert_id => '',
      :paypal_url => 'https://www.paypal.com/cgi-bin/webscr',
      :currency => 'CAD',
      :paypal_cert => "#{Rails.root}/config/paypalcerts/production/paypal_cert.pem",
      :app_cert => "#{Rails.root}/config/paypalcerts/production/app_cert.pem",
      :app_key => "#{Rails.root}/config/paypalcerts/production/app_key.pem"
    }
  else
    config.paypal = {
      :seller_email => '',
      :secret => '',
      :cert_id => '',
      :paypal_url => 'https://www.sandbox.paypal.com/cgi-bin/webscr',
      :currency => 'CAD',
      :paypal_cert => "#{Rails.root}/config/paypalcerts/#{Rails.env}/paypal_cert.pem",
      :app_cert => "#{Rails.root}/config/paypalcerts/#{Rails.env}/app_cert.pem",
      :app_key => "#{Rails.root}/config/paypalcerts/#{Rails.env}/app_key.pem"
    }
  end

  # Stripe configuration
  config.stripe_enabled = false

  if Rails.env.production?
    config.stripe = {
      :secret_key => '',
      :publishable_key => '',
      :currency => 'usd'
    }
  else
    config.stripe = {
      :secret_key => '',
      :publishable_key => '',
      :currency => 'usd'
    }
  end

end
