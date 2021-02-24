require 'effective_addresses'
require 'effective_resources'
require 'effective_orders/engine'
require 'effective_orders/version'

module EffectiveOrders
  # Order states
  PENDING = 'pending'        # New orders are created in a pending state
  CONFIRMED = 'confirmed'    # Once the order has passed checkout step 1
  DEFERRED = 'deferred'      # Deferred providers. Cheque or Phone was selected.
  PURCHASED = 'purchased'    # Purchased by provider
  DECLINED = 'declined'      # Declined by provider
  STATES = { PENDING => PENDING, CONFIRMED => CONFIRMED, DEFERRED => DEFERRED, PURCHASED => PURCHASED, DECLINED => DECLINED }

  # Subscription statuses (as per stripe)
  ACTIVE = 'active'
  PAST_DUE = 'past_due'
  TRIALING = 'trialing'
  CANCELED = 'canceled'

  STATUSES = { ACTIVE => ACTIVE, PAST_DUE => PAST_DUE, CANCELED => CANCELED, TRIALING => TRIALING }

  def self.config_keys
    [
      :orders_table_name, :order_items_table_name, :carts_table_name, :cart_items_table_name,
      :customers_table_name, :subscriptions_table_name, :products_table_name,
      :layout, :mailer_class_name, :mailer,
      :orders_collection_scope, :order_tax_rate_method,
      :obfuscate_order_ids, :use_effective_qb_sync,
      :billing_address, :shipping_address, :use_address_full_name,
      :collect_note, :collect_note_required, :collect_note_message,
      :terms_and_conditions, :terms_and_conditions_label, :minimum_charge,

      # Features
      :free_enabled, :mark_as_paid_enabled, :pretend_enabled, :pretend_message,
      # Payment processors. false or Hash
      :cheque, :moneris, :paypal, :phone, :refund, :stripe, :subscriptions, :trial
    ]
  end

  include EffectiveGem

  def self.permitted_params
    @permitted_params ||= [
      :cc, :note, :terms_and_conditions, :confirmed_checkout,
      billing_address: EffectiveAddresses.permitted_params,
      shipping_address: EffectiveAddresses.permitted_params,
      subscripter: [:stripe_plan_id, :stripe_token]
    ]
  end

  def self.cheque?
    cheque.kind_of?(Hash)
  end

  def self.free?
    free_enabled == true
  end

  def self.deferred?
    deferred_providers.present?
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

  def self.phone?
    phone.kind_of?(Hash)
  end

  def self.pretend?
    pretend_enabled == true
  end

  def self.refund?
    refund.kind_of?(Hash)
  end

  def self.stripe?
    stripe.kind_of?(Hash)
  end

  def self.subscriptions?
    subscriptions.kind_of?(Hash)
  end

  def self.trial?
    trial.kind_of?(Hash)
  end

  def self.single_payment_processor?
    [moneris?, paypal?, stripe?].select { |enabled| enabled }.length == 1
  end

  # The Effective::Order.payment_provider value must be in this collection
  def self.payment_providers
    [
      ('cheque' if cheque?),
      ('credit card' if mark_as_paid?),
      ('free' if free?),
      ('moneris' if moneris?),
      ('paypal' if paypal?),
      ('phone' if phone?),
      ('pretend' if pretend?),
      ('refund' if refund?),
      ('stripe' if stripe?),
      ('other' if mark_as_paid?),
      'none'
    ].compact
  end

  def self.deferred_providers
    [('cheque' if cheque?), ('phone' if phone?)].compact
  end

  def self.mailer
    name = mailer_class_name.presence || 'Effective::OrdersMailer'
    name.safe_constantize || raise("unable to constantize mailer class. check config.mailer_class_name")
  end

  def self.can_skip_checkout_step1?
    return false if require_billing_address
    return false if require_shipping_address
    return false if collect_note
    return false if terms_and_conditions
    true
  end

  def self.stripe_plans
    return [] unless (stripe? && subscriptions?)

    @stripe_plans ||= (
      Rails.logger.info '[STRIPE] index plans'

      plans = begin
        Stripe::Plan.respond_to?(:all) ? Stripe::Plan.all : Stripe::Plan.list
      rescue => e
        raise e if Rails.env.production?
        Rails.logger.info "[STRIPE ERROR]: #{e.message}"
        Rails.logger.info "[STRIPE ERROR]: effective_orders continuing with empty stripe plans. This would fail loudly in Rails.env.production."
        []
      end

      plans = plans.map do |plan|
        description = ("$#{'%0.2f' % (plan.amount / 100.0)}" + ' ' + plan.currency.upcase + '/' +  plan.interval.to_s)

        {
          id: plan.id,
          product_id: plan.product,
          name: plan.nickname || description,
          description: description,
          amount: plan.amount,
          currency: plan.currency,
          interval: plan.interval,
          interval_count: plan.interval_count,
          trial_period_days: (plan.trial_period_days if plan.respond_to?(:trial_period_days))
        }
      end.sort do |x, y|
        val ||= (x[:interval] <=> y[:interval])
        val = nil if val == 0

        val ||= (x[:amount] <=> y[:amount])
        val = nil if val == 0

        val ||= (x[:name] <=> y[:name])
        val = nil if val == 0

        val || (x[:id] <=> y[:id])
      end

      # Calculate savings for any yearly per user plans, based on their matching monthly plans
      plans.select { |plan| plan[:interval] == 'year' }.each do |yearly|
        monthly_name = yearly[:name].downcase.gsub('year', 'month')
        monthly = plans.find { |plan| plan[:interval] == 'month' && plan[:name].downcase == monthly_name }
        next unless monthly

        savings = (monthly[:amount].to_i * 12) - yearly[:amount].to_i
        next unless savings > 0

        yearly[:savings] = savings
      end

      plans
    )
  end

  def self.stripe_plans_collection
    stripe_plans.map { |plan| [plan[:name], plan[:id]] }
  end

  class SoldOutException < Exception; end
  class AlreadyPurchasedException < Exception; end
end
