module Effective
  module Providers
    module Pretend
      extend ActiveSupport::Concern

      def pretend_purchase
        @order ||= Order.find(params[:id])

        EffectiveOrders.authorized?(self, :update, @order)

        order_purchased(
          details: 'for pretend',
          provider: 'pretend',
          card: 'none',
          redirect_url: params[:purchased_redirect_url],
          declined_redirect_url: params[:declined_redirect_url]
        )
      end

    end
  end
end
