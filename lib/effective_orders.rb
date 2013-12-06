require 'effective_addresses'
require "effective_orders/engine"
require 'migrant'     # Required for rspec to run properly

module EffectiveOrders
  PURCHASED = 'purchased'
  DECLINED = 'declined'

  # The following are all valid config keys
  mattr_accessor :orders_table_name
  mattr_accessor :order_items_table_name
  mattr_accessor :carts_table_name
  mattr_accessor :cart_items_table_name
  mattr_accessor :customers_table_name

  mattr_accessor :authorization_method

  mattr_accessor :require_billing_address
  mattr_accessor :require_shipping_address

  mattr_accessor :paypal_enabled
  mattr_accessor :moneris_enabled
  mattr_accessor :stripe_enabled

  # These are hashes of configs
  mattr_accessor :paypal
  mattr_accessor :moneris
  mattr_accessor :stripe

  mattr_accessor :order_id_nudge

  def self.setup
    yield self
  end

  def self.authorized?(controller, action, resource)
    raise ActiveResource::UnauthorizedAccess.new('') unless (controller || self).instance_exec(controller, action, resource, &EffectiveOrders.authorization_method)
    true
  end

  class SoldOutException < Exception; end
  class AlreadyPurchasedException < Exception; end
  class AlreadyDeclinedException < Exception; end

end
