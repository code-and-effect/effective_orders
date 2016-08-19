module Effective
  module Providers
    module Ccbill
      extend ActiveSupport::Concern

      included do
        if respond_to?(:skip_before_action)
          skip_before_action :verify_authenticity_token, only: [:ccbill_postback]
        else
          skip_before_filter :verify_authenticity_token, only: [:ccbill_postback]
        end
      end

      def ccbill_postback
        postback = Effective::Providers::CcbillPostback.new(params)
        @order ||= Effective::Order.find(postback.order_id)

        (EffectiveOrders.authorized?(self, :update, @order) rescue false)

        if @order.present? && postback.verified?
          if @order.purchased?
            order_purchased(details: postback.order_details, provider: 'ccbill')
          elsif postback.approval? && postback.matches?(@order)
            order_purchased(details: postback.order_details, provider: 'ccbill')
          else
            order_declined(details: postback.order_details, provider: 'ccbill')
          end
        end

        head(:ok)
      end
    end

  end
end

