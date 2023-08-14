module Effective
  module Providers
    module MonerisCheckout
      extend ActiveSupport::Concern

      def moneris_checkout
        raise('moneris_checkout provider is not available') unless EffectiveOrders.moneris_checkout?

        @order = Order.find(params[:id])

        # We do this even if we're not authorized.
        EffectiveResources.authorized?(self, :update, @order)

        payment = moneris_checkout_receipt_request(moneris_checkout_params[:ticket])
        purchased = (1..49).include?(payment['response_code'].to_i) # Must be > 0 and < 50 to be valid. Sometimes we get the string 'null'

        if purchased == false
          return order_declined(
            payment: payment,
            provider: 'moneris_checkout',
            declined_url: moneris_checkout_params[:declined_url]
          )
        end

        if payment['card_type'].present?
          active_card = "**** **** **** #{payment['first6last4'].to_s.last(4)} #{payment['card_type']} #{payment['expiry_date'].to_s.first(2)}/#{payment['expiry_date'].to_s.last(2)}"
          payment = payment.except('first6last4').merge('active_card' => active_card)
        end

        order_purchased(
          payment: payment,
          provider: 'moneris_checkout',
          card: payment['card_type'],
          purchased_url: moneris_checkout_params[:purchased_url],
          current_user: current_user
        )
      end

      private

      def moneris_checkout_params
        params.require(:moneris_checkout).permit(:ticket, :purchased_url, :declined_url)
      end

      def moneris_checkout_receipt_request(ticket)
        params = {
          environment: EffectiveOrders.moneris_checkout.fetch(:environment),

          api_token: EffectiveOrders.moneris_checkout.fetch(:api_token),
          store_id: EffectiveOrders.moneris_checkout.fetch(:store_id),
          checkout_id: EffectiveOrders.moneris_checkout.fetch(:checkout_id),

          action: :receipt,
          ticket: ticket
        }

        response = Effective::Http.post(EffectiveOrders.moneris_request_url, params: params)
        response = response['response'] if response

        raise("moneris receipt error #{response}") unless response && response['success'].to_s == 'true'

        response.dig('receipt', 'cc') || response.dig('receipt', 'gift') || response
      end

    end
  end
end
