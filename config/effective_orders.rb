# EffectiveOrders Rails Engine

EffectiveOrders.setup do |config|
  # Configure Database Tables
  config.orders_table_name = :orders
  config.order_items_table_name = :order_items
  config.carts_table_name = :carts
  config.cart_items_table_name = :cart_items
  config.customers_table_name = :customers
  config.subscriptions_table_name = :subscriptions
  config.products_table_name = :products

  # Authorization Method
  #
  # This method is called by all controller actions with the appropriate action and resource
  # If the method returns false, an Effective::AccessDenied Error will be raised (see README.md for complete info)
  #
  # Use via Proc (and with CanCan):
  # config.authorization_method = Proc.new { |controller, action, resource| can?(action, resource) }
  #
  # Use via custom method:
  # config.authorization_method = :my_authorization_method
  #
  # And then in your application_controller.rb:
  #
  # def my_authorization_method(action, resource)
  #   current_user.is?(:admin)
  # end
  #
  # Or disable the check completely:
  # config.authorization_method = false
  config.authorization_method = Proc.new { |controller, action, resource| authorize!(action, resource) } # CanCanCan

  # Layout Settings
  # Configure the Layout per controller, or all at once

  # config.layout = 'application'   # All EffectiveOrders controllers will use this layout
  config.layout = {
    carts: 'application',
    orders: 'application',
    subscriptions: 'application',
    admin_customers: 'admin',
    admin_orders: 'admin'
  }

  # Filter the @orders on admin/orders#index screen
  # config.orders_collection_scope = Proc.new { |scope| scope.where(...) }

  # Require these addresses when creating a new Order.  Works with effective_addresses gem
  config.billing_address = true
  config.shipping_address = false
  config.use_address_full_name = true

  # Use effective_obfuscation gem to change order.id into a seemingly random 10-digit number
  config.obfuscate_order_ids = false

  # If set, the orders#new screen will render effective/orders/_order_note_fields to capture any Note info
  config.collect_note = false
  config.collect_note_required = false
  config.collect_note_message = ''

  # If true, the orders#new screen will render effective/orders/_terms_and_conditions_fields to require a Terms of Service boolean
  # config.terms_and_conditions_label can be a String or a Proc
  # config.terms_and_conditions_label = Proc.new { |order| "Yes, I agree to the #{link_to 'terms and conditions', terms_and_conditions_path}." }
  config.terms_and_conditions = false
  config.terms_and_conditions_label = 'I agree to the terms and conditions.'

  # Tax Calculation Method
  # The Effective::TaxRateCalculator considers the order.billing_address and assigns a tax based on country & state code
  # Right now, only Canadian provinces are supported. Sorry.
  # To always charge 12.5% tax: Proc.new { |order| 12.5 }
  # To always charge 0% tax: Proc.new { |order| 0 }
  # If the Proc returns nil, the tax rate will be calculated once again whenever the order is validated
  # An order must have a tax rate (even if the value is 0) to be purchased
  config.order_tax_rate_method = Proc.new { |order| Effective::TaxRateCalculator.new(order: order).tax_rate }

  # Minimum Charge
  # Prevent orders less than this value from being purchased
  # Stripe doesn't allow orders less than $0.50
  # Set to nil for no minimum charge
  # Default value is 50 cents, or $0.50
  config.minimum_charge = 50

  # Free Orders
  # Allow orders with a total of 0.00 to be purchased (regardless of the minimum charge setting)
  config.free_enabled = true

  # Mark as Paid
  # Mark an order as paid without going through a processor
  # This is accessed via the admin screens only. Must have can?(:admin, :effective_orders)
  config.mark_as_paid_enabled = false

  # Pretend Purchase
  # Display a 'Purchase order' button on the Checkout screen allowing the user
  # to purchase an Order without going through the payment processor.
  # WARNING: Setting this option to true will allow users to purchase! an Order without entering a credit card
  # WARNING: When true, users can purchase! anything without paying money
  config.pretend_enabled = !Rails.env.production?
  config.pretend_message = '* payment information is not required to process this order at this time.'

  # Mailer Settings
  # effective_orders sends out receipts to buyers and admins as well as trial and subscription related emails.
  # For all the emails, the same :subject_prefix will be prefixed.  Leave as nil / empty string if you don't want any prefix
  #
  # All the subject_* keys below can one of:
  # - nil / empty string to use the built in defaults
  # - A string with the full subject line for this email
  # - A Proc to create the subject line based on the email
  # The subject_prefix will then be applied ontop of these.
  #
  # send_order_receipt_to_buyer: Proc.new { |order| "Order #{order.to_param} has been purchased"}
  # subject_for_subscription_payment_succeeded: Proc.new { |order| "Order #{order.to_param} has been purchased"}

  # subject_for_subscription_trialing: Proc.new { |subscribable| "Pending Order #{order.to_param}"}

  config.mailer = {
    send_order_receipt_to_admin: true,
    send_order_receipt_to_buyer: true,
    send_payment_request_to_buyer: true,
    send_pending_order_invoice_to_buyer: true,
    send_order_receipts_when_mark_as_paid: false,

    send_subscription_event_to_admin: true,
    send_subscription_created: true,
    send_subscription_updated: true,
    send_subscription_canceled: true,
    send_subscription_payment_succeeded: true,
    send_subscription_payment_failed: true,

    send_subscription_trialing: true,   # Only if you schedule the rake task to run
    send_subscription_trial_expired: true,    # Only if you schedule the rake task to run

    subject_prefix: '[example]',

    # Procs yield an Effective::Order object
    subject_for_order_receipt_to_admin: '',
    subject_for_order_receipt_to_buyer: '',
    subject_for_payment_request_to_buyer: '',
    subject_for_pending_order_invoice_to_buyer: '',
    subject_for_refund_notification_to_admin: '',

    # Procs yield an Effective::Customer object
    subject_for_subscription_created: '',
    subject_for_subscription_updated: '',
    subject_for_subscription_canceled: '',
    subject_for_subscription_payment_succeeded: '',
    subject_for_subscription_payment_failed: '',

    # Procs yield the acts_as_subscribable object
    subject_for_subscription_trialing: '',
    subject_for_subscription_trial_expired: '',

    layout: 'effective_orders_mailer_layout',

    default_from: 'info@example.com',
    admin_email: 'admin@example.com',   # Refund notifications will also be sent here

    deliver_method: nil  # When nil, will use deliver_later if active_job is configured, otherwise deliver_now
  }

  #######################################
  ## Payment Provider specific options ##
  #######################################

  # Cheque
  # This is an deferred payment
  config.cheque = false

  # config.cheque = {
  #   confirm: 'Proceed with pay by cheque?',
  #   success: 'Thank you! You have indicated that this order will be purchased by cheque. Please send us a cheque and a copy of this invoice at your earliest convenience.'
  # }

  # Moneris
  config.moneris = false

  # if Rails.env.production?
  #   config.moneris = {
  #     ps_store_id: '',
  #     hpp_key: '',
  #     hpp_url: 'https://www3.moneris.com/HPPDP/index.php',
  #     verify_url: 'https://www3.moneris.com/HPPDP/verifyTxn.php'
  #   }
  # else
  #   config.moneris = {
  #     ps_store_id: '',
  #     hpp_key: '',
  #     hpp_url: 'https://esqa.moneris.com/HPPDP/index.php',
  #     verify_url: 'https://esqa.moneris.com/HPPDP/verifyTxn.php'
  #   }
  # end

  # Paypal
  config.paypal = false

  # if Rails.env.production?
  #   config.paypal = {
  #     seller_email: '',
  #     secret: '',
  #     cert_id: '',
  #     paypal_url: 'https://www.paypal.com/cgi-bin/webscr',
  #     currency: 'CAD',
  #     paypal_cert: "#{Rails.root}/config/paypalcerts/production/paypal_cert.pem",
  #     app_cert: "#{Rails.root}/config/paypalcerts/production/app_cert.pem",
  #     app_key: "#{Rails.root}/config/paypalcerts/production/app_key.pem"
  #   }
  # else
  #   config.paypal = {
  #     seller_email: '',
  #     secret: '',
  #     cert_id: '',
  #     paypal_url: 'https://www.sandbox.paypal.com/cgi-bin/webscr',
  #     currency: 'CAD',
  #     paypal_cert: "#{Rails.root}/config/paypalcerts/#{Rails.env}/paypal_cert.pem",
  #     app_cert: "#{Rails.root}/config/paypalcerts/#{Rails.env}/app_cert.pem",
  #     app_key: "#{Rails.root}/config/paypalcerts/#{Rails.env}/app_key.pem"
  #   }
  # end

  # Phone
  # This is an deferred payment
  config.phone = false

  # config.phone = {
  #   confirm: 'Proceed with pay by phone?',
  #   success: 'Thank you! You have indicated that this order will be purchased by phone. Please give us a call at your earliest convenience.'
  # }


  # Refunds
  # This does not issue a refund with the payment processor at all.
  # Instead, we mark the order as purchased, create a refund object to track it, and
  # send an email to mailer[:admin_email] with instructions to issue a refund
  config.refund = false

  # config.refund = {
  #   success: 'Thank you! Your refund will be processed in the next few business days.'
  # }

  # Stripe
  config.stripe = false

  # if Rails.env.production?
  #   config.stripe = {
  #     secret_key: 'sk_xxx',
  #     publishable_key: 'pk_xxx',
  #     currency: 'usd',
  #     site_title: 'My Site',
  #     site_image: 'logo.png' # A relative or absolute URL pointing to a square image of your brand or product. The recommended minimum size is 128x128px.
  #   }
  # else
  #   config.stripe = {
  #     secret_key: 'sk_test_xxx',
  #     publishable_key: 'pk_test_xxx',
  #     currency: 'usd',
  #     site_title: 'My Site',
  #     site_image: 'logo.png' # A relative or absolute URL pointing to a square image of your brand or product. The recommended minimum size is 128x128px.
  #   }
  # end

  # Subscriptions (https://stripe.com/docs/subscriptions)
  config.subscriptions = false

  # config.subscriptions = {
  #   webhook_secret: 'whsec_xxx',
  #   ignore_livemode: false        # Use this to run test mode in production. careful.
  # }

  # Trial
  config.trial = false

  # config.trial = {
  #   name: 'Free Trial',
  #   description: '45-Day Free Trial',
  #   length: 45.days,
  #   remind_at: [1.day, 3.days, 7.days, 40.days, 44.days],  # Send email notification to trialing owners on day 1, 3, 7 40 and 44. false to disable
  # }

end
