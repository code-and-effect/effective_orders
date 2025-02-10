# EffectiveOrders Rails Engine

EffectiveOrders.setup do |config|
  # Layout Settings
  # config.layout = { application: 'application', admin: 'admin' }

  # Filter the @orders on admin/orders#index screen
  # config.orders_collection_scope = Proc.new { |scope| scope.where(...) }

  # Require these addresses when creating a new Order.  Works with effective_addresses gem
  config.billing_address = true
  config.shipping_address = false

  # Use effective_obfuscation gem to change order.id into a seemingly random 10-digit number
  config.obfuscate_order_ids = false

  # Allow orders to be purchased by organization members
  # This will fallback to EffectiveMemberships.Organization if you have that gem installed
  # config.organization_enabled = false
  # config.organization_class_name = 'Example::Organization'

  # Synchronize with Quickbooks
  config.use_effective_qb_sync = false
  config.use_effective_qb_online = false

  # Display the item name field on the orders#new screen
  config.use_item_names = true

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

  # The tax label displayed on orders
  config.tax_label = "Tax"

  # Credit Card Surcharge
  # Will be applied to all orders based off the after-tax total.
  # Use 2.4 for 2.4% or nil for none
  config.credit_card_surcharge_percent = nil
  config.credit_card_surcharge_qb_item_name = 'Credit Card Surcharge'

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
  # Should be true when using deferred payment providers
  config.mark_as_paid_enabled = false

  # Pretend Purchase
  # Display a 'Purchase order' button on the Checkout screen allowing the user
  # to purchase an Order without going through the payment processor.
  # WARNING: Setting this option to true will allow users to purchase! an Order without entering a credit card
  # WARNING: When true, users can purchase! anything without paying money
  config.pretend_enabled = !Rails.env.production?
  config.pretend_message = '* payment information is not required to process this order at this time.'

  # Mailer Settings
  # Please see config/initializers/effective_resources.rb for default effective_* gem mailer settings
  #
  # Configure the class responsible to send e-mails.
  # config.mailer = 'Effective::OrdersMailer'
  #
  # Override effective_resource mailer defaults
  #
  # config.parent_mailer = nil      # The parent class responsible for sending emails
  # config.deliver_method = nil     # The deliver method, deliver_later or deliver_now
  # config.mailer_layout = nil      # Default mailer layout
  # config.mailer_sender = nil      # Default From value
  # config.mailer_admin = nil       # Default To value for Admin correspondence
  # config.mailer_subject = nil     # Proc.new method used to customize Subject

  config.mailer_layout = 'effective_orders_mailer_layout'

  # Email settings
  config.send_order_receipt_to_admin = true
  config.send_order_receipt_to_buyer = true
  config.send_order_declined_to_admin = false
  config.send_order_declined_to_buyer = false
  config.send_payment_request_to_buyer = true
  config.send_pending_order_invoice_to_buyer = true
  config.send_refund_notification_to_admin = true

  config.send_order_receipts_when_mark_as_paid = true
  config.send_order_receipts_when_free = true

  # Stripe Webhooks controller
  config.send_subscription_events = true

  # These two only take affect if you schedule the rake task to run
  config.send_subscription_trialing = true
  config.send_subscription_trial_expired = true

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

  # Deluxe
  config.deluxe = false

  # config.deluxe = {
  #   environment: (Rails.env.production? ? 'production' : 'sandbox'),
  #   client_id: '',
  #   client_secret: '',
  #   access_token: '',
  #   currency: 'CAD'
  # }

  # Deluxe Delayed
  # This is a deferred payment
  config.deluxe_delayed = false

  # config.deluxe_delayed = {
  #   confirm: 'Save card info for later payment',
  #   success: 'Thank you! You have indicated that this order will be purchased by credit card at a later date. We will save your card information securely and process the payment when the order is ready'
  # }

  # E-transfer
  # This is an deferred payment
  config.etransfer = false

  # config.etransfer = {
  #   confirm: 'Proceed with pay by e-transfer?',
  #   success: 'Thank you! You have indicated that this order will be purchased by e-transfer. Please send us an e-transfer to "payments@example.com" with password "example" at your earliest convenience'
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

  # Moneris Checkout
  config.moneris_checkout = false

  # if Rails.env.production?
  #   config.moneris_checkout = {
  #     environment: 'prod',
  #     store_id: '',
  #     api_token: '',
  #     checkout_id: '',
  #   }
  # else
  #   config.moneris_checkout = {
  #     environment: 'qa',
  #     store_id: 'store1',
  #     api_token: 'yesguy1',
  #     checkout_id: 'chktJF76Btore1',
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
  #
  # The historic way of doing refunds was the user would click Accept Refund
  # Which marks the order as purchased and sends an admin the notification to issue a refund with processor
  # To support this, set:
  # config.buyer_purchases_refund = true
  # config.send_refund_notification_to_admin = true
  #
  # The newer way of doing refunds is driven by the admin
  # The user just sees a pending refund and cannot purchase the order
  # The admin does the refund with processor, then uses Admin: Mark as Paid to mark order as purchased thereby completing the refund
  # To support this, set:
  # config.buyer_purchases_refund = false
  # config.send_refund_notification_to_admin = false
  #
  # If you set config.refund = false, Negative order price is set to $0. Can checkout free.
  #
  # You can call order.send_refund_notification! directly or implement a better one in your app
  config.refund = false

  # config.refund = {
  #   success: 'Thank you! Your refund will be processed in the next few business days.',
  #   pending: 'Thank you! Your refund will be processed in the next few business days.'
  # }

  config.buyer_purchases_refund = true
  config.send_refund_notification_to_admin = true  # On Purchase

  # Stripe
  config.stripe = false

  # if Rails.env.production?
  #   config.stripe = {
  #     secret_key: 'sk_xxx',
  #     publishable_key: 'pk_xxx',
  #     currency: 'usd',
  #     remember_card: true,
  #     site_title: 'My Site',
  #     site_image: 'logo.png' # A relative or absolute URL pointing to a square image of your brand or product. The recommended minimum size is 128x128px.
  #   }
  # else
  #   config.stripe = {
  #     secret_key: 'sk_test_xxx',
  #     publishable_key: 'pk_test_xxx',
  #     currency: 'usd',
  #     remember_card: true,
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
