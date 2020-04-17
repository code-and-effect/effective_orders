module EffectiveOrders
  class Engine < ::Rails::Engine
    engine_name 'effective_orders'

    # Include acts_as_addressable concern and allow any ActiveRecord object to call it
    initializer 'effective_orders.active_record' do |app|
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.extend(ActsAsPurchasable::Base)
        ActiveRecord::Base.extend(ActsAsSubscribable::Base)
        ActiveRecord::Base.extend(ActsAsSubscribableBuyer::Base)
      end
    end

    # Set up our default configuration options.
    initializer 'effective_orders.defaults', before: :load_config_initializers do |app|
      eval File.read("#{config.root}/config/effective_orders.rb")
    end

    # Set up mail delivering config option
    initializer 'effective_orders.mailer', after: :load_config_initializers do |app|
      EffectiveOrders.mailer[:deliver_method] ||= (
        (Rails.application.config.respond_to?(:active_job) && Rails.application.config.active_job.queue_adapter) ? :deliver_later : :deliver_now
      )
    end

    initializer "effective_orders.append_precompiled_assets" do |app|
      Rails.application.config.assets.precompile += ['effective_orders/*']
    end

    initializer 'effective_orders.refund', after: :load_config_initializers do
      if EffectiveOrders.refund?
        unless (EffectiveOrders.mailer[:admin_email].to_s.include?('@') rescue false)
          raise("config.mailer[:admin_email] must be present when refunds enabled.")
        end
      end
    end

    initializer 'effective_orders.stripe', after: :load_config_initializers do
      if EffectiveOrders.stripe?
        begin
          require 'stripe'
          ::Stripe.api_key = EffectiveOrders.stripe[:secret_key]
        rescue Exception
          raise "unable to load stripe. Plese add gem 'stripe' to your Gemfile and then 'bundle install'"
        end
      end
    end

    initializer 'effective_orders.obfuscate_order_ids' do
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
