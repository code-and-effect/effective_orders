require 'effective_addresses'
require 'effective_resources'
require 'effective_orders/engine'
require 'effective_orders/version'

module EffectiveOrders

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
      :layout,
      :orders_collection_scope, :order_tax_rate_method,
      :obfuscate_order_ids, :use_effective_qb_sync, :use_effective_qb_online,
      :billing_address, :shipping_address,
      :collect_note, :collect_note_required, :collect_note_message,
      :terms_and_conditions, :terms_and_conditions_label, :minimum_charge,
      :credit_card_surcharge_percent, :credit_card_surcharge_qb_item_name,

      # Organization mode
      :organization_enabled, :organization_class_name,

      # Mailer
      :mailer, :parent_mailer, :deliver_method, :mailer_layout, :mailer_sender, :mailer_admin, :mailer_subject,

      # Emails
      :send_order_receipt_to_admin, :send_order_receipt_to_buyer, 
      :send_order_declined_to_admin, :send_order_declined_to_buyer, 
      :send_payment_request_to_buyer, :send_pending_order_invoice_to_buyer,
      :send_order_receipts_when_mark_as_paid, :send_order_receipts_when_free,
      :send_subscription_events,
      :send_subscription_trialing, :send_subscription_trial_expired,
      :send_refund_notification_to_admin,

      # Features
      :free_enabled, :mark_as_paid_enabled, :pretend_enabled, :pretend_message, :buyer_purchases_refund,

      # Payment processors. false or Hash
      :cheque, :deluxe, :deluxe_delayed, :etransfer, :moneris, :moneris_checkout, :paypal, :phone, :refund, :stripe, :subscriptions, :trial
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

  def self.organization_enabled?
    organization_enabled == true
  end

  def self.Organization
    klass = organization_class_name&.constantize
    klass ||= (EffectiveMemberships.Organization if defined?(EffectiveMemberships))
    raise('Please set the effective_orders config.organization_class_name') if klass.blank?

    klass
  end

  def self.cheque?
    cheque.kind_of?(Hash)
  end

  def self.etransfer?
    etransfer.kind_of?(Hash)
  end

  def self.free?
    free_enabled == true
  end

  def self.deluxe?
    deluxe.kind_of?(Hash)
  end

  def self.deluxe_delayed?
    deluxe_delayed.kind_of?(Hash)
  end

  def self.deferred?
    deferred_providers.present?
  end

  def self.delayed?
    delayed_providers.present?
  end

  def self.mark_as_paid?
    mark_as_paid_enabled == true
  end

  def self.moneris?
    moneris.kind_of?(Hash)
  end

  def self.moneris_checkout?
    moneris_checkout.kind_of?(Hash)
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

  def self.no_refund?
    !refund?
  end

  def self.buyer_purchases_refund?
    buyer_purchases_refund == true
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
    [deluxe?, moneris?, moneris_checkout?, paypal?, stripe?].select { |enabled| enabled }.length == 1
  end

  # The Effective::Order.payment_provider value must be in this collection
  def self.payment_providers
    [
      ('cheque' if cheque?),
      ('credit card' if mark_as_paid?),
      ('deluxe' if deluxe?),
      ('etransfer' if etransfer?),
      ('free' if free?),
      ('moneris' if moneris?),
      ('moneris_checkout' if moneris_checkout?),
      ('paypal' if paypal?),
      ('phone' if phone?),
      ('pretend' if pretend?),
      ('refund' if refund?),
      ('stripe' if stripe?),
      ('other' if mark_as_paid?),
      'none'
    ].compact
  end

  # For the Admin Mark as Paid screen
  def self.admin_payment_providers
    [
      ('cheque' if mark_as_paid?),
      ('credit card' if mark_as_paid?),
      ('deluxe' if deluxe?),
      ('etransfer' if etransfer?),
      #('free' if free?),
      ('moneris' if moneris?),
      ('moneris_checkout' if moneris_checkout?),
      ('paypal' if paypal?),
      ('phone' if mark_as_paid?),
      #('pretend' if pretend?),
      #('refund' if refund?),
      ('stripe' if stripe?),
      ('other (non credit card)' if mark_as_paid?),
      'none'
    ].compact
  end

  # Should not include delayed providers
  def self.deferred_providers
    [('cheque' if cheque?), ('etransfer' if etransfer?), ('phone' if phone?)].compact
  end

  def self.delayed_providers
    [('deluxe_delayed' if deluxe_delayed?)].compact
  end

  def self.credit_card_payment_providers
    ['credit card', 'deluxe', 'moneris', 'moneris_checkout', 'paypal', 'stripe']
  end

  def self.qb_sync?
    use_effective_qb_sync && defined?(EffectiveQbSync)
  end

  def self.qb_online?
    use_effective_qb_online && defined?(EffectiveQbOnline)
  end

  def self.surcharge?
    credit_card_surcharge_percent.to_f > 0.0
  end

  def self.mailer_class
    mailer&.constantize || Effective::OrdersMailer
  end

  def self.can_skip_checkout_step1?
    return false if require_billing_address
    return false if require_shipping_address
    return false if collect_note
    return false if terms_and_conditions
    true
  end

  def self.with_stripe(&block)
    raise('expected stripe to be enabled') unless stripe?

    begin
      ::Stripe.api_key = stripe[:secret_key]
      yield
    ensure
      ::Stripe.api_key = nil
    end
  end

  def self.stripe_plans
    return [] unless (stripe? && subscriptions?)

    @stripe_plans ||= (
      Rails.logger.info '[STRIPE] index plans'

      plans = begin
        Stripe::Plan.respond_to?(:all) ? Stripe::Plan.all : Stripe::Plan.list
      rescue Exception => e
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

  def self.deluxe_script_url
    case EffectiveOrders.deluxe.fetch(:environment)
    when 'production' then 'https://hostedpaymentform.deluxe.com/v2/deluxe.js'
    when 'sandbox' then 'https://hostedform2.deluxe.com/V2/deluxe.js'
    else raise('unexpected EffectiveOrders.deluxe :environment key. Please check your config/initializers/effective_orders.rb file')
    end
  end

  def self.moneris_checkout_script_url
    case EffectiveOrders.moneris_checkout.fetch(:environment)
    when 'prod' then 'https://gateway.moneris.com/chktv2/js/chkt_v2.00.js'
    when 'qa' then 'https://gatewayt.moneris.com/chktv2/js/chkt_v2.00.js'
    else raise('unexpected EffectiveOrders.moneris_checkout :environment key. Please check your config/initializers/effective_orders.rb file')
    end
  end

  def self.moneris_request_url
    case EffectiveOrders.moneris_checkout.fetch(:environment)
    when 'prod' then 'https://gateway.moneris.com/chktv2/request/request.php'
    when 'qa' then 'https://gatewayt.moneris.com/chktv2/request/request.php'
    else raise('unexpected EffectiveOrders.moneris_checkout :environment key. Please check your config/initializers/effective_orders.rb file')
    end
  end

  class SoldOutException < Exception; end

end
