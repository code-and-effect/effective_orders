module Effective
  module Providers
    module Recaptcha
      extend ActiveSupport::Concern

      def verify_recaptcha_action
        raise('recaptcha is not enabled') unless EffectiveOrders.recaptcha?

        @order = Effective::Order.deep.was_not_purchased.find(params[:id])
        EffectiveResources.authorize!(self, :update, @order)

        if verify_recaptcha(secret_key: EffectiveOrders.recaptcha_secret_key)
          session[:recaptcha_verified_order_id] = @order.id
          redirect_to effective_orders.order_path(@order)
        else
          flash[:danger] = 'Verification failed. Please try again.'
          redirect_to effective_orders.order_path(@order)
        end
      end
    end
  end
end
