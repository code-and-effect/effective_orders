module EffectiveOrders
  class Engine < ::Rails::Engine
    engine_name 'effective_orders'

    # Include acts_as_addressable concern and allow any ActiveRecord object to call it
    initializer 'effective_orders.active_record' do |app|
      app.config.to_prepare do
        ActiveSupport.on_load :active_record do
          ActiveRecord::Base.extend(ActsAsPurchasable::Base)
          ActiveRecord::Base.extend(ActsAsPurchasableParent::Base)
          ActiveRecord::Base.extend(ActsAsSubscribable::Base)
          ActiveRecord::Base.extend(ActsAsSubscribableBuyer::Base)
        end
      end
    end

    # Set up our default configuration options.
    initializer 'effective_orders.defaults', before: :load_config_initializers do |app|
      eval File.read("#{config.root}/config/effective_orders.rb")
    end

    initializer 'effective_orders.assets' do |app|
      app.config.assets.precompile += ['effective_orders_manifest.js', 'effective_orders/*']
    end

    initializer 'effective_orders.refund', after: :load_config_initializers do
      if EffectiveOrders.refund?
        unless (EffectiveOrders.mailer_admin.to_s.include?('@') rescue false)
          raise("config.mailer_admin must be present when refunds enabled.")
        end
      end
    end

    initializer 'effective_orders.stripe', after: :load_config_initializers do
      if EffectiveOrders.stripe?
        begin
          require 'stripe'
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
