module Effective
  module Providers
    module Phone
      extend ActiveSupport::Concern

      def phone
        @order ||= Order.find(params[:id])

        EffectiveOrders.authorize!(self, :update, @order)

        flash[:success] = EffectiveOrders.phone[:success]

        order_deferred(provider: 'phone', deferred_url: phone_params[:deferred_url])
      end

      def phone_params
        params.require(:phone).permit(:deferred_url)
      end

    end
  end
end
