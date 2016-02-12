require 'haml-rails'
require 'simple_form'
require 'effective_addresses'
require 'effective_orders/engine'
require 'effective_orders/version'
require 'effective_orders/app_checkout_service'

module EffectiveOrders
  PURCHASED = 'purchased'
  DECLINED = 'declined'
  PENDING = 'pending'

  # The following are all valid config keys
  mattr_accessor :orders_table_name
  mattr_accessor :order_items_table_name
  mattr_accessor :carts_table_name
  mattr_accessor :cart_items_table_name
  mattr_accessor :customers_table_name
  mattr_accessor :subscriptions_table_name
  mattr_accessor :products_table_name

  mattr_accessor :authorization_method
  mattr_accessor :skip_mount_engine
  mattr_accessor :orders_collection_scope

  mattr_accessor :order_tax_rate_method

  mattr_accessor :layout
  mattr_accessor :simple_form_options
  mattr_accessor :admin_simple_form_options

  mattr_accessor :use_active_admin
  mattr_accessor :active_admin_namespace

  mattr_accessor :obfuscate_order_ids
  mattr_accessor :silence_deprecation_warnings

  mattr_accessor :allow_pretend_purchase_in_development
  mattr_accessor :allow_pretend_purchase_in_production
  mattr_accessor :allow_pretend_purchase_in_production_message

  mattr_accessor :require_billing_address
  mattr_accessor :require_shipping_address
  mattr_accessor :use_address_full_name

  mattr_accessor :collect_user_fields
  mattr_accessor :skip_user_validation

  mattr_accessor :collect_note
  mattr_accessor :collect_note_required
  mattr_accessor :collect_note_message

  mattr_accessor :minimum_charge
  mattr_accessor :allow_free_orders
  mattr_accessor :show_order_history_button

  mattr_accessor :cheque_enabled
  mattr_accessor :paypal_enabled
  mattr_accessor :moneris_enabled
  mattr_accessor :ccbill_enabled
  mattr_accessor :app_checkout_enabled

  mattr_accessor :stripe_enabled
  mattr_accessor :stripe_subscriptions_enabled
  mattr_accessor :stripe_connect_enabled

  # application fee is required if stripe_connect_enabled is true
  mattr_accessor :stripe_connect_application_fee_method

  # These are hashes of configs
  mattr_accessor :mailer
  mattr_accessor :paypal
  mattr_accessor :moneris
  mattr_accessor :stripe
  mattr_accessor :ccbill
  mattr_accessor :app_checkout
  mattr_accessor :cheque

  mattr_accessor :deliver_method

  def self.setup
    yield self

    if EffectiveOrders.stripe_enabled
      ::Stripe.api_key = stripe[:secret_key]
    end
  end

  def self.authorized?(controller, action, resource)
    if authorization_method.respond_to?(:call) || authorization_method.kind_of?(Symbol)
      raise Effective::AccessDenied.new() unless (controller || self).instance_exec(controller, action, resource, &authorization_method)
    end
    true
  end

  def self.minimum_charge
    if @@minimum_charge.nil? || @@minimum_charge.kind_of?(Integer)
      @@minimum_charge
    else
      ActiveSupport::Deprecation.warn('EffectiveOrders.minimum_charge config option is a non-integer. It should be an Integer representing the number of cents.  Continuing with (price * 100.0).round(0).to_i conversion') unless EffectiveOrders.silence_deprecation_warnings
      ((@@minimum_charge * 100.0).round(0).to_i rescue nil)
    end
  end

  def self.use_active_admin?
    use_active_admin && defined?(ActiveAdmin)
  end

  def self.permitted_params
    [
      :note, :save_billing_address, :save_shipping_address, :shipping_address_same_as_billing,
      billing_address: [:full_name, :address1, :address2, :city, :country_code, :state_code, :postal_code],
      shipping_address: [:full_name, :address1, :address2, :city, :country_code, :state_code, :postal_code],
      user_attributes: (EffectiveOrders.collect_user_fields || []),
      order_items_attributes: [:stripe_coupon_id, :class, :id]
    ]
  end

  def self.single_payment_processor?
    [
      moneris_enabled,
      paypal_enabled,
      stripe_enabled,
      cheque_enabled,
      ccbill_enabled,
      app_checkout_enabled
    ].select { |enabled| enabled }.length == 1
  end

  # The Effective::Order.payment_provider value must be in this collection
  def self.payment_providers
    @payment_providers ||= [
      'admin',
      ('app_checkout' if app_checkout_enabled),
      ('ccbill' if ccbill_enabled),
      ('cheque' if cheque_enabled),
      ('free' if allow_free_orders),
      ('moneris' if moneris_enabled),
      ('paypal' if paypal_enabled),
      ('pretend' if (allow_pretend_purchase_in_production && Rails.env.production?) || (allow_pretend_purchase_in_development && !Rails.env.production?)),
      ('stripe' if stripe_enabled),
      ('stripe_connect' if stripe_connect_enabled)
    ].compact
  end

  def self.tax_rate_method=(*args)
    raise 'EffectiveOrders.tax_rate_method has been removed and renamed to EffectiveOrders.order_tax_rate_method.  Its expected value is now different too. Return 5.25 for 5.25% tax. Please refer to the readme for more info.'
  end

  class SoldOutException < Exception; end
  class AlreadyPurchasedException < Exception; end
  class AlreadyDeclinedException < Exception; end

end
