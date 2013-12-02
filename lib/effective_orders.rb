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

  mattr_accessor :authorization_method

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
