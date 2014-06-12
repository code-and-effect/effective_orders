# EffectiveOrders Rails Engine

EffectiveOrders.setup do |config|
  # Configure Database Tables
  config.orders_table_name = :orders
  config.order_items_table_name = :order_items
  config.carts_table_name = :carts
  config.cart_items_table_name = :cart_items
  config.customers_table_name = :customers
  config.subscriptions_table_name = :subscriptions

  # Authorization Method
  config.authorization_method = Proc.new { |controller, action, resource| can?(action, resource) } # CanCan gem

  # Require these addresses when creating a new Order.  Works with effective_addresses gem
  config.require_billing_address = true
  config.require_shipping_address = false

  # If set, the orders#new screen will render effective/orders/user_fields partial and capture this User Info
  # The partial can be overridden to customize the form, but the following fields are also fed into strong_paramters
  config.collect_user_fields = []
  #config.collect_user_fields = [:salutation, :first_name, :last_name] # Must be valid fields on the User object

  # Don't validate_associated :user when saving an Order
  config.skip_user_validation = false

  # For use with development testing, pass the order ID plus this to the payment processor
  config.order_id_nudge = 0

  # Tax Calculation Method
  config.tax_rate_method = Proc.new { |acts_as_purchasable| 0.05 } # Regardless of the object, charge 5% tax (GST)

  # Layout Settings
  # Configure the Layout per controller, or all at once

  # config.layout = 'application'   # All EffectiveOrders controllers will use this layout

  config.layout = {
    :carts => 'application',
    :orders => 'application',
    :subscriptions => 'application',
    :admin_customers => 'application',
    :admin_orders => 'application'
  }

  # Mailer Settings
  config.mailer = {
    :send_order_receipt_to_admin => true,
    :send_order_receipt_to_buyer => true,
    :send_order_receipt_to_seller => true,   # Only applies to StripeConnect
    :admin_email => 'admin@example.com',
    :default_from => 'info@example.com',
    :subject_prefix => '[example]'
  }

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
  config.stripe_subscriptions_enabled = false # https://stripe.com/docs/subscriptions
  config.stripe_connect_enabled = false # https://stripe.com/docs/connect
  config.stripe_connect_application_fee_method = Proc.new { |order_item| order_item.total * 0.10 } # 10 percent

  if Rails.env.production?
    config.stripe = {
      :secret_key => '',
      :publishable_key => '',
      :currency => 'usd',
      :site_title => 'My Site',
      :site_image => '', # A relative URL pointing to a square image of your brand or product. The recommended minimum size is 128x128px.
      :connect_client_id => ''
    }
  else
    config.stripe = {
      :secret_key => '',
      :publishable_key => '',
      :currency => 'usd',
      :site_title => 'My Development Site',  # Displayed on the Embedded Stripe Form
      :site_image => '', # A relative URL pointing to a square image of your brand or product. The recommended minimum size is 128x128px.
      :connect_client_id => ''
    }
  end

end
