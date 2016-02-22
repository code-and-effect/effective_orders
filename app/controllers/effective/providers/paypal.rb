module Effective
  module Providers
    module Paypal
      extend ActiveSupport::Concern

      included do
        skip_before_filter :verify_authenticity_token, :only => [:paypal_postback]

        if defined?(CanCan)
          skip_authorization_check only: [:paypal_postback]
        end
      end

      def paypal_postback
        @order ||= Effective::Order.where(id: (params[:invoice].to_i rescue 0)).first

        if @order.present?
          if @order.purchased?
            order_purchased(details: params, provider: 'paypal', card: params[:payment_type])
          elsif (params[:payment_status] == 'Completed' && params[:custom] == EffectiveOrders.paypal[:secret])
            order_purchased(details: params, provider: 'paypal', card: params[:payment_type])
          else
            order_declined(details: params, provider: 'paypal', card: params[:payment_type])
          end
        end

        head(:ok)
      end


    end
  end
end
