module Effective
  module Providers
    module Paypal
      extend ActiveSupport::Concern

      included do
        skip_before_filter :verify_authenticity_token, :only => [:paypal_postback]
      end

      def paypal_postback
        @order ||= Effective::Order.where(:id => params[:invoice].to_i - EffectiveOrders.order_nudge_id.to_i).first

        EffectiveOrders.authorized?(self, :create, @order)

        if @order.present?
          if params[:payment_status] == 'Completed' && params[:custom] == EffectiveOrders.paypal[:secret]
            @order.purchased(params)
            @order.user.cart.try(:destroy)
          else
            @order.declined(params)
          end
        end

        head(:ok)
      end


    end
  end
end
