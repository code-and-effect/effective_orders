module Effective
  module Providers
    module Phone
      extend ActiveSupport::Concern

      def phone
        @order ||= Order.find(params[:id])

        EffectiveOrders.authorize!(self, :update, @order)

        unless @order.free?
          flash[:danger] = 'Unable to process free order with a non-zero total'
          redirect_to effective_orders.order_path(@order)
          return
        end

        order_purchased(
          payment: 'free order. no payment required.',
          provider: 'free',
          card: 'none',
          purchased_url: free_params[:purchased_url],
          declined_url: free_params[:declined_url],
          email: false
        )
      end

      def free_params
        params.require(:free).permit(:purchased_url, :declined_url)
      end

    end
  end
end
