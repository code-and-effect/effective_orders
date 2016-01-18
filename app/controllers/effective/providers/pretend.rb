module Effective
  module Providers
    module Pretend
      extend ActiveSupport::Concern

      def pretend_purchase
        @order ||= Order.find(params[:id])
        EffectiveOrders.authorized?(self, :update, @order)

        order_purchased('for pretend', params[:purchased_redirect_url], params[:declined_redirect_url])
      end

    end
  end
end
