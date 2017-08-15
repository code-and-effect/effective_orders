require 'simple_form'
require 'effective_addresses'
require 'effective_orders/engine'
require 'effective_orders/version'
require 'effective_orders/app_checkout_service'

module EffectiveOrders
  ABANDONED = 'abandoned'
  PURCHASED = 'purchased'
  DECLINED = 'declined'
  PENDING = 'pending'

  PURCHASE_STATES = { nil => ABANDONED, PURCHASED => PURCHASED, DECLINED => DECLINED, PENDING => PENDING }

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
  mattr_accessor :show_order_history_button

  mattr_accessor :obfuscate_order_ids

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

  mattr_accessor :terms_and_conditions
  mattr_accessor :terms_and_conditions_label

  mattr_accessor :minimum_charge
  mattr_accessor :allow_free_orders
  mattr_accessor :allow_refunds

  mattr_accessor :app_checkout_enabled
  mattr_accessor :ccbill_enabled
  mattr_accessor :cheque_enabled
  mattr_accessor :mark_as_paid_enabled
  mattr_accessor :moneris_enabled
  mattr_accessor :paypal_enabled

  mattr_accessor :stripe_enabled
  mattr_accessor :stripe_subscriptions_enabled
  mattr_accessor :stripe_connect_enabled

  # application fee is required if stripe_connect_enabled is true
  mattr_accessor :stripe_connect_application_fee_method

  # These are hashes of configs
  mattr_accessor :app_checkout
  mattr_accessor :ccbill
  mattr_accessor :cheque
  mattr_accessor :mailer
  mattr_accessor :moneris
  mattr_accessor :paypal
  mattr_accessor :stripe

  mattr_accessor :deliver_method

  def self.setup
    yield self
  end

  def self.authorized?(controller, action, resource)
    if authorization_method.respond_to?(:call) || authorization_method.kind_of?(Symbol)
      raise Effective::AccessDenied.new() unless (controller || self).instance_exec(controller, action, resource, &authorization_method)
    end
    true
  end

  def self.permitted_params
    [
      :note, :terms_and_conditions,
      billing_address: EffectiveAddresses.permitted_params,
      shipping_address: EffectiveAddresses.permitted_params,
      user_attributes: (EffectiveOrders.collect_user_fields || []),
      subscripter: [:stripe_plan_id, :stripe_token]
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

  # One of these is used when Admin marks as paid
  def self.other_payment_providers
    ['credit card', 'none', 'other']
  end

  def self.can_skip_checkout_step1?
    return false if require_billing_address
    return false if require_shipping_address
    return false if collect_note
    return false if terms_and_conditions
    return false if collect_user_fields.present?

    true
  end

  # We query stripe for the plans just once and cache it forever.
  def self.stripe_blank_plan
    stripe_plans['blank'] || {}
  end

  def self.stripe_plans
    return {} unless (stripe_enabled && stripe_subscriptions_enabled)

    @stripe_plans ||= (
      plans = Stripe::Plan.all.inject({}) do |h, plan|
        occurrence = case plan.interval
          when 'daily'    ; '/day'
          when 'weekly'   ; '/week'
          when 'monthly'  ; '/month'
          when 'yearly'   ; '/year'
          when 'day'      ; plan.interval_count == 1 ? '/day' : " every #{plan.interval_count} days"
          when 'week'     ; plan.interval_count == 1 ? '/week' : " every #{plan.interval_count} weeks"
          when 'month'    ; plan.interval_count == 1 ? '/month' : " every #{plan.interval_count} months"
          when 'year'     ; plan.interval_count == 1 ? '/year' : " every #{plan.interval_count} years"
          else            ; plan.interval
        end

        h[plan.id] = {
          id: plan.id,
          name: plan.name,
          amount: plan.amount,
          currency: plan.currency,
          description: "$#{'%0.2f' % (plan.amount / 100.0)} #{plan.currency.upcase}#{occurrence}",
          occurrence: "#{occurrence}",
          interval: plan.interval,
          interval_count: plan.interval_count
        }; h
      end

      plans['blank'] = {
        id: 'blank',
        name: 'Free Trial',
        amount: 0,
        description: '45-Day Free Trial'
      }

      plans
    )
  end

  class SoldOutException < Exception; end
  class AlreadyPurchasedException < Exception; end
end
