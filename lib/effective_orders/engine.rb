module EffectiveOrders
  class Engine < ::Rails::Engine
    engine_name 'effective_orders'

    config.autoload_paths += Dir["#{config.root}/app/models/**/"]

    # Include Helpers to base application
    initializer 'effective_orders.action_controller' do |app|
      ActiveSupport.on_load :action_controller do
        helper EffectiveOrdersHelper
        helper EffectiveCartsHelper
        helper EffectivePaypalHelper if EffectiveOrders.paypal_enabled
        helper EffectiveStripeHelper if EffectiveOrders.stripe_enabled
        helper EffectiveCcbillHelper if EffectiveOrders.ccbill_enabled
      end
    end

    # Include acts_as_addressable concern and allow any ActiveRecord object to call it
    initializer 'effective_orders.active_record' do |app|
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.extend(ActsAsPurchasable::ActiveRecord)
      end
    end

    initializer 'effective_orders.action_view' do |app|
      ActiveSupport.on_load :action_view do
        ActionView::Helpers::FormBuilder.send(:include, Inputs::PriceFormInput)
      end
    end

    # Set up our default configuration options.
    initializer "effective_orders.defaults", before: :load_config_initializers do |app|
      eval File.read("#{config.root}/lib/generators/templates/effective_orders.rb")
    end

    # Set up mail delivering config option
    initializer "effective_orders.mailer", after: :load_config_initializers do |app|
      deliver_method = Rails.gem_version >= Gem::Version.new('4.2') ? :deliver_now : :deliver
      EffectiveOrders.mailer[:deliver_method] ||= deliver_method
    end

    # Set up our Stripe API Key
    initializer "effective_orders.stripe_api_key", after: :load_config_initializers do |app|
      if EffectiveOrders.stripe_enabled
        begin
          require 'stripe'
        rescue Exception
          raise "unable to load stripe.  Plese add gem 'stripe' to your Gemfile and then 'bundle install'"
        end
      end
    end

    initializer 'effective_orders.moneris_config_validation', after: :load_config_initializers do
      if EffectiveOrders.moneris_enabled
        unless EffectiveOrders.moneris.is_a?(Hash)
          raise ArgumentError, "expected EffectiveOrders.moneris to be a Hash but it is a #{EffectiveOrders.moneris.class}"
        end
        missing = EffectiveOrders.moneris.select {|_config, value| value.blank? }

        raise "Missing effective_orders Moneris configuration values: #{missing.keys.join(', ')}" if missing.present?
      end
    end

    initializer 'effective_orders.paypal_config_validation', after: :load_config_initializers do
      if EffectiveOrders.paypal_enabled
        unless EffectiveOrders.paypal.is_a?(Hash)
          raise ArgumentError, "expected EffectiveOrders.paypal to be a Hash but it is a #{EffectiveOrders.paypal.class}"
        end
        missing = EffectiveOrders.paypal.select {|_config, value| value.blank? }

        raise "Missing effective_orders PayPal configuration values: #{missing.keys.join(', ')}" if missing.present?
      end
    end

    initializer 'effective_orders.stripe_config_validation', after: :load_config_initializers do
      if EffectiveOrders.stripe_enabled
        unless EffectiveOrders.stripe.is_a?(Hash)
          raise ArgumentError, "expected EffectiveOrders.stripe to be a Hash but it is a #{EffectiveOrders.stripe.class}"
        end
        missing = EffectiveOrders.stripe.select {|_config, value| value.blank? }
        required = [:secret_key, :publishable_key, :currency, :site_title]
        stripe_connect_required = [:connect_client_id]
        required += stripe_connect_required if EffectiveOrders.stripe_connect_enabled

        # perform an intersection operation between missing and required configs
        missing_required = missing.keys & required
        raise "Missing effective_orders Stripe configuration values: #{missing_required.join(', ')}" if missing_required.present?
      end
    end

    initializer 'effective_orders.ccbill_config_validation', after: :load_config_initializers do
      if EffectiveOrders.ccbill_enabled
        unless EffectiveOrders.ccbill.is_a?(Hash)
          raise ArgumentError, "expected EffectiveOrders.ccbill to be a Hash but it is a #{EffectiveOrders.ccbill.class}"
        end
        EffectiveOrders.ccbill[:form_period] ||= 365

        missing = EffectiveOrders.stripe.select {|_config, value| value.blank? }
        required = [:client_accnum, :client_subacc, :form_name, :currency_code, :dynamic_pricing_salt]

        # perform an intersection operation between missing and required configs
        missing_required = missing.keys & required
        raise "Missing effective_orders Stripe configuration values: #{missing_required.join(', ')}" if missing_required.present?
      end
    end

    initializer 'effective_orders.app_checkout_config_validation', after: :load_config_initializers do
      if EffectiveOrders.app_checkout_enabled
        unless EffectiveOrders.app_checkout.is_a?(Hash)
          raise ArgumentError, "expected EffectiveOrders.app_checkout to be a Hash but it is a #{EffectiveOrders.app_checkout.class}"
        end
        missing = EffectiveOrders.app_checkout.select {|_config, value| value.blank? }
        missing = missing | [:service] unless EffectiveOrders.app_checkout.has_key?(:service)

        raise "Missing effective_orders App Checkout configuration values: #{missing.keys.join(', ')}" if missing.present?
        unless EffectiveOrders.app_checkout[:service].respond_to?(:call)
          msg = "EffectiveOrders.app_checkout[:service] is not a compatible service object. Inherit from EffectiveOrders::AppCheckoutService or implement a similar API"
          raise ArgumentError, msg
        end
      end
    end

    initializer 'effective_orders.cheque_config_validation', after: :load_config_initializers do
      if EffectiveOrders.cheque_enabled
        unless EffectiveOrders.cheque.is_a?(Hash)
          raise ArgumentError, "expected EffectiveOrders.cheque to be a Hash but it is a #{EffectiveOrders.cheque.class}"
        end
      end
    end

    initializer 'effective_orders.obfuscate_order_ids_validation' do
      if EffectiveOrders.obfuscate_order_ids
        begin
          require 'effective_obfuscation'
        rescue Exception
          raise "unable to load effective_obfuscation.  Plese add gem 'effective_obfuscation' to your Gemfile and then 'bundle install'"
        end
      end
    end

    # Use ActiveAdmin (optional)
    initializer 'effective_orders.active_admin' do
      if EffectiveOrders.use_active_admin?
        begin
          require 'activeadmin'
        rescue Exception
          raise "unable to load activeadmin.  Plese add gem 'activeadmin' to your Gemfile and then 'bundle install'"
        end

        ActiveAdmin.application.load_paths.unshift *Dir["#{config.root}/active_admin"]

        Rails.application.config.to_prepare do
          ActiveSupport.on_load :action_controller do
            ApplicationController.extend(ActsAsActiveAdminController::ActionController)
            Effective::OrdersController.send(:acts_as_active_admin_controller, 'orders')
            Effective::CartsController.send(:acts_as_active_admin_controller, 'carts')
          end
        end

      end
    end

  end
end
