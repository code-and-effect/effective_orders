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

        binding.pry

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

      # {"type"=>"Token", "status"=>"success", "data"=>{"token"=>"1983661243624242", "nameOnCard"=>"CardHolder", "expDate"=>"12/24", "maskedPan"=>"424242******4242", "cardType"=>"Visa"}}

      # Stripe Payment
      # 
      # {"charge_id"=>"ch_3PCMnpAQ1WnX5L9p0hizlzrR", "payment_method_id"=>"pm_1PCMo6AQ1WnX5L9pZaqiTT4p", "payment_intent_id"=>"pi_3PCMnpAQ1WnX5L9p0V1ccbUi", "active_card"=>"**** **** **** 5018 visa 11/2026", "card"=>"visa", "amount"=>44070, "created"=>1714745391, "currency"=>"cad", "customer"=>"cus_NOn0UHCIBLJtrd", "status"=>"succeeded"}
      # card: 'visa'
      #
      # Moneris Checkout
      # {"order_no"=>"50733-evan-edlund-1714732703-7278", "cust_id"=>8056, "transaction_no"=>"80014-0_408", "reference_no"=>"661194130019820010", "transaction_code"=>"00", "transaction_type"=>"200", "transaction_date_time"=>"2024-05-03 04:38:41", "corporate_card"=>nil, "amount"=>"530.25", "response_code"=>"027", "iso_response_code"=>"01", "approval_code"=>"052414", "card_type"=>"M", "dynamic_descriptor"=>nil, "invoice_number"=>nil, "customer_code"=>nil, "eci"=>"7", "cvd_result_code"=>"1M", "avs_result_code"=>nil, "cavv_result_code"=>nil, "expiry_date"=>"0524", "recur_success"=>nil, "issuer_id"=>nil, "is_debit"=>"false", "ecr_no"=>"66119413", "batch_no"=>"982", "sequence_no"=>"001", "result"=>"a", "fraud"=>{"3d_secure"=>{"decision_origin"=>"Merchant", "result"=>"3", "condition"=>"1", "status"=>"disabled", "code"=>"", "details"=>""}, "kount"=>{"decision_origin"=>"Merchant", "result"=>"3", "condition"=>nil, "status"=>"disabled", "code"=>"", "details"=>""}, "cvd"=>{"decision_origin"=>"Merchant", "result"=>"1", "condition"=>"0", "status"=>"success", "code"=>"1M", "details"=>""}, "avs"=>{"decision_origin"=>"Merchant", "result"=>"3", "condition"=>"0", "status"=>"disabled", "code"=>"", "details"=>""}}, "active_card"=>"**** **** **** 5975 M 05/24"}
      # "**** **** **** 5975 M 05/24"
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
      end

      def process_deluxe_vault_payment(payment_intent)
        customer_id = payment_intent.dig('data', 'customerId') || raise('expected a customerID')
        vault_id = payment_intent.dig('data', 'vaultId') || raise('expected a vaultID')
      end

      #   intent = EffectiveOrders.with_stripe { ::Stripe::PaymentIntent.retrieve(payment_intent_id) }
      #   raise('expected stripe intent to be present') if intent.blank?
      #   return unless intent.status == 'succeeded'

      #   # Stripe API version 2022-11-15 and 2022-08-01
      #   charge_id = intent.try(:latest_charge) || (intent.charges.data.first.id rescue nil)
      #   raise('expected stripe charge_id to be present') if charge_id.blank?

      #   charge = EffectiveOrders.with_stripe { ::Stripe::Charge.retrieve(charge_id) }
      #   raise('expected stripe charge to be present') if charge.blank?
      #   return unless charge.status == 'succeeded'

      #   card = charge.payment_method_details.try(:card) || {}
      #   active_card = "**** **** **** #{card['last4']} #{card['brand']} #{card['exp_month']}/#{card['exp_year']}" if card.present?

      #   {
      #     charge_id: charge.id,
      #     payment_method_id: charge.payment_method,
      #     payment_intent_id: intent.id,

      #     active_card: active_card,
      #     card: card['brand'],

      #     amount: charge.amount,
      #     created: charge.created,
      #     currency: charge.currency,
      #     customer: charge.customer,
      #     status: charge.status
      #   }.compact
      # end

    end
  end
end
