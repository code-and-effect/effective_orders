# This is an object for the stripe charge form
module Effective
  class StripeCharge
    extend ActiveModel::Naming
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveRecord::Reflection
    
    attr_accessor :effective_order_id, :order, :token # For our form

    validates_presence_of :effective_order_id, :token

    def initialize(params = {})
      if params.kind_of?(Effective::Order)
        @order = params
        @effective_order_id = params.id
      else
        params.each { |k, v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
      end
    end

    def persisted?
      false
    end

    def order_items
      order.order_items.reject { |order_item| order_item.purchasable.kind_of?(Effective::Subscription) }
    end

    def subscriptions
      order.order_items.select { |order_item| order_item.purchasable.kind_of?(Effective::Subscription) }.map(&:purchasable)
    end

  end
end
