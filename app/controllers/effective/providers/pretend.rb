module Effective
  module Providers
    module Pretend
      extend ActiveSupport::Concern

      def pretend
        raise('pretend provider is not available') unless EffectiveOrders.pretend?

        @order ||= Order.deep.find(params[:id])

        EffectiveResources.authorize!(self, :update, @order)

        if params[:commit].to_s.include?('Decline')
          order_declined(
            payment: 'for pretend', 
            provider: 'pretend', 
            card: 'none', 
            declined_url: pretend_params[:declined_url]
          )
        else
          order_purchased(
            payment: 'for pretend', 
            provider: 'pretend', 
            card: 'none', 
            purchased_url: pretend_params[:purchased_url],
            current_user: current_user
          )
        end
      end

      def pretend_params
        params.require(:pretend).permit(:purchased_url, :declined_url)
      end

    end
  end
end
