module Effective
  module Providers
    module Pretend
      extend ActiveSupport::Concern

      def pretend
        @order ||= Order.find(params[:id])

        EffectiveOrders.authorize!(self, :update, @order)

        order_purchased(
          payment: 'for pretend',
          provider: 'pretend',
          card: 'none',
          purchased_url: params[:purchased_url],
          declined_url: params[:declined_url]
        )
      end

    end
  end
end
