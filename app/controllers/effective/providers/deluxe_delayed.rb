module Effective
  module Providers
    module DeluxeDelayed
      extend ActiveSupport::Concern

      def deluxe_delayed
        raise('deluxe provider is not available') unless EffectiveOrders.deluxe?
        raise('deluxe_delayed provider is not available') unless EffectiveOrders.deluxe_delayed?

        @order = Effective::Order.deep.find(params[:id])

        EffectiveResources.authorize!(self, :update, @order)

        ## Process Payment Intent
        api = Effective::DeluxeApi.new

        # The payment_intent is set by the Deluxe HostedPaymentForm
        payment_intent_payload = deluxe_delayed_params[:payment_intent]

        if payment_intent_payload.blank?
          flash[:danger] = 'Unable to process deluxe delayed order without payment intent. please try again.'
          return order_not_processed(declined_url: deluxe_delayed_params[:declined_url])
        end

        # Decode the base64 encoded JSON object into a Hash
        payment_intent = api.decode_payment_intent_payload(payment_intent_payload)
        card_info = api.card_info(payment_intent)

        valid = payment_intent['status'] == 'success'

        if valid == false
          return order_declined(payment: card_info, provider: 'deluxe_delayed', card: card_info['card'], declined_url: deluxe_delayed_params[:declined_url])
        end

        flash[:success] = EffectiveOrders.deluxe_delayed[:success]

        order_delayed(payment: card_info, payment_intent: payment_intent_payload, provider: 'deluxe_delayed', card: card_info['card'], deferred_url: deluxe_delayed_params[:deferred_url])
      end

      private

      def deluxe_delayed_params
        params.require(:deluxe_delayed).permit(:payment_intent, :deferred_url, :declined_url)
      end

    end
  end
end
