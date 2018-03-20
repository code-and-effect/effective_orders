require 'effective_addresses'
require 'effective_orders/engine'
require 'effective_orders/version'

module EffectiveOrders
  PENDING = 'pending'.freeze
  CONFIRMED = 'confirmed'.freeze
  PURCHASED = 'purchased'.freeze
  DECLINED = 'declined'.freeze

  STATES = { PENDING => PENDING, CONFIRMED => CONFIRMED, PURCHASED => PURCHASED, DECLINED => DECLINED }

  # The following are all valid config keys
  mattr_accessor :orders_table_name
  mattr_accessor :order_items_table_name
  mattr_accessor :carts_table_name
  mattr_accessor :cart_items_table_name
  mattr_accessor :customers_table_name
  mattr_accessor :subscriptions_table_name
  mattr_accessor :products_table_name

  mattr_accessor :authorization_method

  mattr_accessor :pretend_purchase_in_development_enabled
  mattr_accessor :pretend_purchase_in_production_enabled
  mattr_accessor :pretend_purchase_in_production_message

  mattr_accessor :layout
  mattr_accessor :mailer

  mattr_accessor :orders_collection_scope
  mattr_accessor :order_tax_rate_method

  mattr_accessor :obfuscate_order_ids
  mattr_accessor :billing_address
  mattr_accessor :shipping_address
  mattr_accessor :use_address_full_name

  mattr_accessor :collect_user_fields
  mattr_accessor :skip_user_validation

  mattr_accessor :collect_note
  mattr_accessor :collect_note_required
  mattr_accessor :collect_note_message

  mattr_accessor :terms_and_conditions
  mattr_accessor :terms_and_conditions_label

  mattr_accessor :minimum_charge
  mattr_accessor :free_enabled
  mattr_accessor :mark_as_paid_enabled
  mattr_accessor :refunds_enabled

  # Payment processors. false or Hash
  mattr_accessor :cheque
  mattr_accessor :moneris
  mattr_accessor :paypal
  mattr_accessor :stripe
  mattr_accessor :subscriptions  # Stripe subscriptions

  def self.setup
    yield self
  end

  def self.authorized?(controller, action, resource)
    @_exceptions ||= [Effective::AccessDenied, (CanCan::AccessDenied if defined?(CanCan)), (Pundit::NotAuthorizedError if defined?(Pundit))].compact

    return !!authorization_method unless authorization_method.respond_to?(:call)
    controller = controller.controller if controller.respond_to?(:controller)

    begin
      !!(controller || self).instance_exec((controller || self), action, resource, &authorization_method)
    rescue *@_exceptions
      false
    end
  end

  def self.authorize!(controller, action, resource)
    raise Effective::AccessDenied unless authorized?(controller, action, resource)
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

  def self.cheque?
    cheque.kind_of?(Hash)
  end

  def self.free?
    free_enabled == true
  end

  def self.mark_as_paid?
    mark_as_paid_enabled == true
  end

  def self.moneris?
    moneris.kind_of?(Hash)
  end

  def self.paypal?
    paypal.kind_of?(Hash)
  end

  def self.pretend?
    (pretend_purchase_in_production_enabled && Rails.env.production?) || (pretend_purchase_in_development_enabled && !Rails.env.production?)
  end

  def self.refunds?
    refunds_enabled == true
  end

  def self.stripe?
    stripe.kind_of?(Hash)
  end

  def self.subscriptions?
    subscriptions.kind_of?(Hash)
  end

  def self.single_payment_processor?
    [cheque?, moneris?, paypal?, stripe?].select { |enabled| enabled }.length == 1
  end

  # The Effective::Order.payment_provider value must be in this collection
  def self.payment_providers
    [
      ('cheque' if cheque?),
      ('free' if free?),
      ('moneris' if moneris?),
      ('paypal' if paypal?),
      ('pretend' if pretend?),
      ('stripe' if stripe?),
      ('credit card' if mark_as_paid?),
      ('none' if mark_as_paid?),
      ('other' if mark_as_paid?),
    ].compact
  end

  def self.can_skip_checkout_step1?
    return false if require_billing_address
    return false if require_shipping_address
    return false if collect_note
    return false if terms_and_conditions
    return false if collect_user_fields.present?
    true
  end

  def self.stripe_plans
    return {} unless (stripe? && subscriptions?)

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

      plans['trial'] = {
        id: 'trial',
        amount: 0,
        name: (subscriptions[:trial_name] || 'Free Trial'),
        description: (subscriptions[:trial_description] || 'Free Trial')
      }

      plans
    )
  end

  class SoldOutException < Exception; end
  class AlreadyPurchasedException < Exception; end
end
