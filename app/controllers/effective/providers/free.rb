module Effective
  module Providers
    module Free
      extend ActiveSupport::Concern

      def free
        @order ||= Order.find(params[:id])

        EffectiveOrders.authorized?(self, :update, @order)

        unless @order.free?
          flash[:danger] = 'Unable to process free order with a non-zero total'
          redirect_to effective_orders.order_path(@order)
          return
        end

        order_purchased(
          details: 'free order. no payment required.',
          provider: 'free',
          card: 'none',
          purchased_url: params[:purchased_url].presence || effective_orders.admin_order_path(@order),
          declined_url: params[:declined_url].presence || effective_orders.admin_order_path(@order),
          email: false
        )
      end

      def free_params
        params.require(:effective_order).permit(:purchased_url, :declined_url)
      end

    end
  end
end
