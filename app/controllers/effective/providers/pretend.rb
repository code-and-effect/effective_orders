module Effective
  module Providers
    module Pretend
      extend ActiveSupport::Concern

      def pretend
        raise('pretend provider is not available') unless EffectiveOrders.pretend?

        @order ||= Order.find(params[:id])

        EffectiveResources.authorize!(self, :update, @order)

        order_purchased(
          payment: 'for pretend',
          provider: 'pretend',
          card: 'none',
          purchased_url: pretend_params[:purchased_url]
        )
      end

      def pretend_params
        params.require(:pretend).permit(:purchased_url, :declined_url)
      end

    end
  end
end
