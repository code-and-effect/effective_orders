module Effective
  module Providers
    module Refund
      extend ActiveSupport::Concern

      def refund
        raise('refund provider is not available') unless EffectiveOrders.refund?
        raise('refund provider is not configured for buyer purchase') unless EffectiveOrders.buyer_purchases_refund?

        @order ||= Order.deep.find(params[:id])
        @order.current_user = current_user unless admin_checkout?(refund_params)

        EffectiveResources.authorize!(self, :update, @order)

        unless @order.refund?
          flash[:danger] = 'Unable to process refund order with a positive total'
          redirect_to effective_orders.order_path(@order)
          return
        end

        flash[:success] = EffectiveOrders.refund[:success].presence

        order_purchased(
          payment: 'refund. no payment required.',
          provider: 'refund',
          purchased_url: refund_params[:purchased_url]
        )
      end

      def refund_params
        params.require(:refund).permit(:purchased_url, :declined_url)
      end

    end
  end
end
