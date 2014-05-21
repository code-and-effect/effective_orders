module EffectiveOrders
  class Engine < ::Rails::Engine
    engine_name 'effective_orders'

    config.autoload_paths += Dir["#{config.root}/app/models/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/models/validators"]

    # Include Helpers to base application
    initializer 'effective_orders.action_controller' do |app|
      ActiveSupport.on_load :action_controller do
        helper EffectiveOrdersHelper
        helper EffectiveCartsHelper
        helper EffectivePaypalHelper
        helper EffectiveStripeHelper
      end
    end

    # Include acts_as_addressable concern and allow any ActiveRecord object to call it
    initializer 'effective_orders.active_record' do |app|
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.extend(ActsAsPurchasable::ActiveRecord)
      end
    end

    # Set up our default configuration options.
    initializer "effective_orders.defaults", :before => :load_config_initializers do |app|
      eval File.read("#{config.root}/lib/generators/templates/effective_orders.rb")
    end

    # Set up our Stripe API Key
    initializer "effective_orders.stripe_api_key", :after => :load_config_initializers do |app|
      if EffectiveOrders.stripe_enabled
        require 'stripe'
        ::Stripe.api_key = EffectiveOrders.stripe[:secret_key]
      end
    end


    # ActiveAdmin (optional)
    # This prepends the load path so someone can override the assets.rb if they want.
    initializer 'effective_orders.active_admin' do
      if defined?(ActiveAdmin)
        ActiveAdmin.application.load_paths.unshift Dir["#{config.root}/active_admin"]
      end
    end

  end
end
