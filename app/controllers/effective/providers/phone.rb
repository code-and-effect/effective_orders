module Effective
  module Providers
    module Phone
      extend ActiveSupport::Concern

      def phone
        raise('phone provider is not available') unless EffectiveOrders.phone?

        @order ||= Order.deep.find(params[:id])

        EffectiveResources.authorize!(self, :update, @order)

        flash[:success] = EffectiveOrders.phone[:success]

        order_deferred(provider: 'phone', deferred_url: phone_params[:deferred_url])
      end

      def phone_params
        params.require(:phone).permit(:deferred_url)
      end

    end
  end
end
