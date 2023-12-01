module Effective
  module Providers
    module Cheque
      extend ActiveSupport::Concern

      def cheque
        raise('cheque provider is not available') unless EffectiveOrders.cheque?

        @order ||= Order.deep.find(params[:id])

        EffectiveResources.authorize!(self, :update, @order)

        flash[:success] = EffectiveOrders.cheque[:success]

        order_deferred(provider: 'cheque', deferred_url: cheque_params[:deferred_url])
      end

      def cheque_params
        params.require(:cheque).permit(:deferred_url)
      end

    end
  end
end
