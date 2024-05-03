module Effective
  module Providers
    module Deluxe
      extend ActiveSupport::Concern

      def deluxe
        raise('deluxe provider is not available') unless EffectiveOrders.deluxe?

        @order = Order.deep.find(params[:id])
        @customer = Effective::Customer.for_user(@order.user || current_user)

        EffectiveResources.authorize!(self, :update, @order)

        payment_intent = deluxe_params[:payment_intent]

        if payment_intent.blank?
          flash[:danger] = 'Unable to process deluxe order without payment. please try again.'
          return order_not_processed(declined_url: payment_intent[:declined_url])
        end

        # Decode the base64 encoded JSON object into a Hash
        payment_intent = (JSON.parse(Base64.decode64(payment_intent)) rescue nil)
        raise('expected payment_intent to be a Hash') unless payment_intent.kind_of?(Hash)

        # Process the payment intent
        payment = process_deluxe_payment(payment_intent)

        if payment.blank?
          return order_declined(payment: payment, provider: 'deluxe', declined_url: deluxe_params[:declined_url])
        end

        # # Update the customer payment fields
        # TODO
        # if payment[:payment_method_id].present?
        #   @customer.update!(payment.slice(:payment_method_id, :active_card))
        # end

        order_purchased(
          payment: payment,
          provider: 'deluxe',
          card: payment[:card],
          purchased_url: deluxe_params[:purchased_url],
          current_user: (current_user unless admin_checkout?(deluxe_params))
        )
      end

      private

      def deluxe_params
        params.require(:deluxe).permit(:payment_intent, :purchased_url, :declined_url)
      end

      # {"type"=>"Token", "status"=>"success", "data"=>{"token"=>"1983661243624242", "nameOnCard"=>"CardHolder", "expDate"=>"12/24", "maskedPan"=>"424242******4242", "cardType"=>"Visa"}}
      def process_deluxe_payment(payment_intent)
        raise('expected deluxe payment intent to be a Hash') unless payment_intent.kind_of?(Hash)

        # Validate success state
        return unless payment_intent['status'] == 'success'

        # Validate type
        payment_type = payment_intent['type']

        case payment_type
        when "Token" then process_deluxe_token_payment(payment_intent)
        when "Vault" then process_deluxe_vault_payment(payment_intent)
        else
          raise("unsupported payment type: #{payment_type}")
        end
      end

      def process_deluxe_token_payment(payment_intent)
        token = payment_intent.dig('data', 'token') || raise('expected a token')

        last4 = payment_intent.dig('data', 'maskedPan').to_s.last(4)
        card = payment_intent.dig('data', 'cardType').to_s.downcase
        date = payment_intent.dig('data', 'expDate').to_s

        active_card = "**** **** **** #{last4} #{card} #{date}" if last4.present?

        {
          token: token,

          active_card: active_card,
          card: card,

          nameOnCard: payment_intent.dig('data', 'nameOnCard'),
          created: Time.zone.now,
        }.compact

        raise('todo')
      end

      def process_deluxe_vault_payment(payment_intent)
        customer_id = payment_intent.dig('data', 'customerId') || raise('expected a customerID')
        vault_id = payment_intent.dig('data', 'vaultId') || raise('expected a vaultID')

        raise('todo')
      end

    end
  end
end
