module Effective
  module Providers
    module Helcim
      extend ActiveSupport::Concern

      def helcim
        raise('helcim provider is not available') unless EffectiveOrders.helcim?

        @order = Effective::Order.deep.find(params[:id])
        @order.current_user = current_user unless admin_checkout?(helcim_params)

        EffectiveResources.authorize!(self, :update, @order)

        # Process and Verify Payment
        api = Effective::HelcimApi.new

        # Decode the payment payload
        payment_payload = api.decode_payment_payload(helcim_params[:payment])

        if payment_payload.blank?
          flash[:danger] = 'Unable to process helcim order without payment. please try again.'
          return order_not_processed(declined_url: helcim_params[:declined_url])
        end

        # Verify the payment
        payment = api.verify_payment(payment_payload)
        purchased = api.purchased?(payment)

        if purchased == false
          flash[:danger] = "Payment was unsuccessful. The credit card payment failed with message: #{payment['status'] || 'none'}. Please try again."
          return order_declined(
            payment: payment, 
            provider: 'helcim', 
            card: payment['card'], 
            declined_url: helcim_params[:declined_url]
          )
        end

        # Valid Authorized and Completed Payment
        order_purchased(
          payment: payment,
          provider: 'helcim',
          card: payment['card'],
          purchased_url: helcim_params[:purchased_url]
        )
      end

      private

      def helcim_params
        params.require(:helcim).permit(:payment, :purchased_url, :declined_url)
      end

    end
  end
end
