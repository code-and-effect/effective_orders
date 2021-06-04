module EffectiveOrders
  class Engine < ::Rails::Engine
    engine_name 'effective_orders'

    #config.autoload_paths += Dir["#{config.root}/app/models/**/"]

    # Include acts_as_addressable concern and allow any ActiveRecord object to call it
    initializer 'effective_orders.active_record' do |app|
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.extend(ActsAsPurchasable::ActiveRecord)
        ActiveRecord::Base.extend(ActsAsSubscribable::ActiveRecord)
        ActiveRecord::Base.extend(ActsAsSubscribableBuyer::ActiveRecord)
      end
    end

    # Set up our default configuration options.
    initializer 'effective_orders.defaults', before: :load_config_initializers do |app|
      eval File.read("#{config.root}/config/effective_orders.rb")
    end

    initializer 'effective_orders.assets' do |app|
      app.config.assets.precompile += ['effective_orders_manifest.js', 'effective_orders/*']
    end

    # Set up mail delivering config option
    initializer 'effective_orders.mailer', after: :load_config_initializers do |app|
      deliver_method = Rails.gem_version >= Gem::Version.new('4.2') ? :deliver_now : :deliver
      EffectiveOrders.mailer[:deliver_method] ||= deliver_method
    end

    initializer 'effective_orders.moneris_config_validation', after: :load_config_initializers do
      if EffectiveOrders.moneris_enabled
        raise 'expected EffectiveOrders.moneris to be a Hash' unless EffectiveOrders.moneris.is_a?(Hash)

        missing = EffectiveOrders.moneris.select { |_, value| value.blank? }
        raise "Missing EffectiveOrders.moneris config values: #{missing.keys.join(', ')}" if missing.present?
      end
    end

    initializer 'effective_orders.paypal_config_validation', after: :load_config_initializers do
      if EffectiveOrders.paypal_enabled
        raise 'expected EffectiveOrders.paypal to be a Hash' unless EffectiveOrders.paypal.is_a?(Hash)

        missing = EffectiveOrders.paypal.select { |_, value| value.blank? }
        raise "Missing EffectiveOrders.paypal config values: #{missing.keys.join(', ')}" if missing.present?
      end
    end

    initializer 'effective_orders.stripe_config_validation', after: :load_config_initializers do
      if EffectiveOrders.stripe_enabled
        begin
          require 'stripe'
        rescue Exception
          raise "unable to load stripe. Plese add gem 'stripe' to your Gemfile and then 'bundle install'"
        end

        raise 'expected EffectiveOrders.stripe to be a Hash' unless EffectiveOrders.stripe.is_a?(Hash)

        missing = EffectiveOrders.stripe.select { |_, value| value.blank? }
        required = [:secret_key, :publishable_key, :currency, :site_title]
        required += [:connect_client_id] if EffectiveOrders.stripe_connect_enabled

        # perform an intersection operation between missing and required configs
        missing_required = missing.keys & required
        raise "Missing EffectiveOrders.stripe config values: #{missing_required.join(', ')}" if missing_required.present?
      end
    end

    initializer 'effective_orders.stripe_api_key', after: :load_config_initializers do |app|
      if EffectiveOrders.stripe_enabled
        ::Stripe.api_key = EffectiveOrders.stripe[:secret_key]
      end
    end

    initializer 'effective_orders.ccbill_config_validation', after: :load_config_initializers do
      if EffectiveOrders.ccbill_enabled
        raise 'expected EffectiveOrders.ccbill to be a Hash' unless EffectiveOrders.ccbill.is_a?(Hash)

        EffectiveOrders.ccbill[:form_period] ||= 365

        missing = EffectiveOrders.stripe.select { |_, value| value.blank? }
        required = [:client_accnum, :client_subacc, :form_name, :currency_code, :dynamic_pricing_salt]

        # perform an intersection operation between missing and required configs
        missing_required = missing.keys & required
        raise "Missing EffectiveOrders.ccbill config values: #{missing_required.join(', ')}" if missing_required.present?
      end
    end

    initializer 'effective_orders.app_checkout_config_validation', after: :load_config_initializers do
      if EffectiveOrders.app_checkout_enabled
        raise 'expected EffectiveOrders.app_checkout to be a Hash' unless EffectiveOrders.app_checkout.is_a?(Hash)

        missing = EffectiveOrders.app_checkout.select { |_, value| value.blank? }
        missing = missing | [:service] unless EffectiveOrders.app_checkout.has_key?(:service)

        raise "Missing effective_orders App Checkout configuration values: #{missing.keys.join(', ')}" if missing.present?

        unless EffectiveOrders.app_checkout[:service].respond_to?(:call)
          raise 'EffectiveOrders.app_checkout[:service] is not a compatible service object. Inherit from EffectiveOrders::AppCheckoutService or implement a similar API'
        end
      end
    end

    initializer 'effective_orders.cheque_config_validation', after: :load_config_initializers do
      if EffectiveOrders.cheque_enabled
        raise 'expected EffectiveOrders.cheque to be a Hash' unless EffectiveOrders.cheque.is_a?(Hash)
      end
    end

    initializer 'effective_orders.obfuscate_order_ids_validation' do
      if EffectiveOrders.obfuscate_order_ids
        begin
          require 'effective_obfuscation'
        rescue Exception
          raise "unable to load effective_obfuscation. Please add gem 'effective_obfuscation' to your Gemfile and then 'bundle install'"
        end
      end
    end

  end
end
