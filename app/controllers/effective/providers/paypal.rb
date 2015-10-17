module Effective
  module Providers
    module Paypal
      extend ActiveSupport::Concern

      included do
        skip_before_filter :verify_authenticity_token, :only => [:paypal_postback]
      end

      def paypal_postback
        @order ||= Effective::Order.where(id: (params[:invoice].to_i rescue 0)).first

        EffectiveOrders.authorized?(self, :update, @order)

        if @order.present?
          if @order.purchased?
            order_purchased(params)
          elsif (params[:payment_status] == 'Completed' && params[:custom] == EffectiveOrders.paypal[:secret])
            order_purchased(params)
          else
            order_declined(params)
          end
        end

        head(:ok)
      end


    end
  end
end
