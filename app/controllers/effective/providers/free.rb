module Effective
  module Providers
    module Free
      extend ActiveSupport::Concern

      def free
        raise('free provider is not available') unless EffectiveOrders.free?

        @order ||= Order.deep.find(params[:id])
        @order.current_user = current_user unless admin_checkout?(free_params)

        EffectiveResources.authorize!(self, :update, @order)

        unless @order.free?
          flash[:danger] = 'Unable to process free order with a non-zero total'
          redirect_to effective_orders.order_path(@order)
          return
        end

        order_purchased(
          payment: 'free order. no payment required.',
          provider: 'free',
          card: 'none',
          purchased_url: free_params[:purchased_url]
        )
      end

      def free_params
        params.require(:free).permit(:purchased_url, :declined_url)
      end

    end
  end
end
