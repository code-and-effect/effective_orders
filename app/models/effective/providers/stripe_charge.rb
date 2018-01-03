# This is an object for the stripe charge form
module Effective::Providers
  class StripeCharge
    include ActiveModel::Model

    attr_accessor :effective_order_id, :order, :stripe_token # For our form

    validates :effective_order_id, presence: true
    validates :stripe_token, presence: true

    def persisted?
      false
    end

    def effective_order_id
      @effective_order_id || (order.to_param if order)
    end

    def order_items
      order.order_items if order
    end

  end
end
