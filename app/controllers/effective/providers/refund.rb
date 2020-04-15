module Effective
  module Providers
    module Refund
      extend ActiveSupport::Concern

      def refund
        @order ||= Order.find(params[:id])

        EffectiveOrders.authorize!(self, :update, @order)

        unless @order.refund?
          flash[:danger] = 'Unable to process refund order with a positive total'
          redirect_to effective_orders.order_path(@order)
          return
        end

        flash[:success] = EffectiveOrders.refund[:success].presence

        order_purchased(
          payment: 'refund. no payment required.',
          provider: 'refund',
          purchased_url: refund_params[:purchased_url],
          declined_url: refund_params[:declined_url]
        )
      end

      def refund_params
        params.require(:refund).permit(:purchased_url, :declined_url)
      end

    end
  end
end
