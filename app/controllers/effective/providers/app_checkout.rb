module Effective
  module Providers
    module AppCheckout
      extend ActiveSupport::Concern

      included do
        if defined?(CanCan)
          skip_authorization_check only: [:app_checkout]
        end
      end

      def app_checkout
        @order = Order.find(params[:id])
        checkout = EffectiveOrders.app_checkout[:service].call(order: @order)
        if checkout.success?
          order_purchased(details: payment_details(checkout), provider: 'app_checkout', card: 'none')
        else
          flash = EffectiveOrders.app_checkout[:declined_flash]
          order_declined(details: payment_details(checkout), message: flash, provider: 'app_checkout', card: 'none')
        end
      end

      private

      def payment_details(checkout)
        default = 'App Checkout'
        if checkout.respond_to?(:payment_details)
          checkout.payment_details.presence || default
        else
          default
        end
      end
    end
  end
end

