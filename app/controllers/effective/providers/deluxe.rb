module Effective
  module Providers
    module Deluxe
      extend ActiveSupport::Concern

      def deluxe
        raise('deluxe provider is not available') unless EffectiveOrders.deluxe?

        @order = Effective::Order.deep.find(params[:id])

        EffectiveResources.authorize!(self, :update, @order)

        ## Process Payment Intent
        api = Effective::DeluxeApi.new

        # The payment_intent is set by the Deluxe HostedPaymentForm
        payment_intent_payload = deluxe_params[:payment_intent]

        if payment_intent_payload.blank?
          flash[:danger] = 'Unable to process deluxe order without payment. please try again.'
          return order_not_processed(declined_url: deluxe_params[:declined_url])
        end

        # Decode the base64 encoded JSON object into a Hash
        payment_intent = api.decode_payment_intent_payload(payment_intent_payload)
        card_info = api.card_info(payment_intent)

        valid = (payment_intent['status'] == 'success')

        if valid == false
          return order_declined(payment: card_info, provider: 'deluxe', card: card_info['card'], declined_url: deluxe_params[:declined_url])
        end

        ## Purchase Order right now
        purchased = api.purchase!(@order, payment_intent)

        payment = api.payment
        raise('expected a payment Hash') unless payment.kind_of?(Hash)

        if purchased == false
          flash[:danger] = "Payment was unsuccessful. The credit card payment failed with message: #{Array(payment['responseMessage']).to_sentence.presence || 'none'}. Please try again."
          return order_declined(payment: payment, provider: 'deluxe', card: payment['card'], declined_url: deluxe_params[:declined_url])
        end

        # Valid Authorized and Completed Payment
        order_purchased(
          payment: payment,
          provider: 'deluxe',
          card: payment['card'],
          purchased_url: deluxe_params[:purchased_url],
          current_user: (current_user unless admin_checkout?(deluxe_params))
        )
      end

      private

      def deluxe_params
        params.require(:deluxe).permit(:payment_intent, :purchased_url, :declined_url)
      end

    end
  end
end
