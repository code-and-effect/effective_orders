module Effective
  module Providers
    module Ccbill
      extend ActiveSupport::Concern

      included do
        skip_before_filter :verify_authenticity_token, :only => [:ccbill_postback]
      end

      def ccbill_postback
        postback = Effective::CcbillPostback.new(params)
        @order ||= Effective::Order.find(postback.order_id)

        EffectiveOrders.authorized?(self, :update, @order)

        if @order.present? && postback.verified?
          if @order.purchased?
            order_purchased(postback.order_details)
          elsif postback.approval? && postback.matches?(@order)
            order_purchased(postback.order_details)
          else
            order_declined(postback.order_details)
          end
        end

        head(:ok)
      end
    end

  end
end

