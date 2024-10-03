module Effective
  module Providers
    module Paypal
      extend ActiveSupport::Concern

      included do
        skip_before_action :verify_authenticity_token, only: [:paypal_postback]
      end

      # TODO: Make paypal postback work with admin checkout workflow

      def paypal_postback
        raise('paypal provider is not available') unless EffectiveOrders.paypal?

        @order ||= Effective::Order.deep.where(id: (params[:invoice].to_i rescue 0)).first
        @order.current_user = current_user unless admin_checkout?(paypal_params)

        # We do this even if we're not authorized
        EffectiveResources.authorized?(self, :update, @order)

        if @order.present?
          if @order.purchased?
            order_purchased(payment: params, provider: 'paypal', card: params[:payment_type])
          elsif (params[:payment_status] == 'Completed' && params[:custom] == EffectiveOrders.paypal[:secret])
            order_purchased(payment: params, provider: 'paypal', card: params[:payment_type])
          else
            order_declined(payment: params, provider: 'paypal', card: params[:payment_type])
          end
        end

        head(:ok)
      end

      def paypal_params
        {}
      end

    end
  end
end
