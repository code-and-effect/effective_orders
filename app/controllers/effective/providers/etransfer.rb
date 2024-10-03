module Effective
  module Providers
    module Etransfer
      extend ActiveSupport::Concern

      def etransfer
        raise('etransfer provider is not available') unless EffectiveOrders.etransfer?

        @order ||= Order.deep.find(params[:id])
        @order.current_user = current_user unless admin_checkout?(etransfer_params)

        EffectiveResources.authorize!(self, :update, @order)

        flash[:success] = EffectiveOrders.etransfer[:success]

        order_deferred(provider: 'etransfer', deferred_url: etransfer_params[:deferred_url])
      end

      def etransfer_params
        params.require(:etransfer).permit(:deferred_url)
      end

    end
  end
end
