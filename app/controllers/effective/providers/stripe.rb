module Effective
  module Providers
    module Stripe
      extend ActiveSupport::Concern

      def stripe
        raise('stripe provider is not available') unless EffectiveOrders.stripe?

        @order = Order.find(params[:id])
        @customer = Effective::Customer.for_user(@order.user)

        EffectiveResources.authorize!(self, :update, @order)

        payment = validate_stripe_payment(stripe_params[:payment_intent_id])

        if payment.blank? || !payment.kind_of?(Hash)
          return order_declined(payment: payment, provider: 'stripe', declined_url: stripe_params[:declined_url])
        end

        # Update the customer payment fields
        if payment[:payment_method_id].present?
          @customer.update!(payment.slice(:payment_method_id, :active_card))
        end

        order_purchased(
          payment: payment,
          provider: 'stripe',
          card: payment[:card],
          purchased_url: stripe_params[:purchased_url]
        )
      end

      private

      def stripe_params
        params.require(:stripe).permit(:payment_intent_id, :purchased_url, :declined_url)
      end

      def validate_stripe_payment(payment_intent_id)
        begin
          intent = ::Stripe::PaymentIntent.retrieve(payment_intent_id)
          raise('status is not succeeded') unless intent.status == 'succeeded'
          raise('charges are not present') unless intent.charges.present?

          charge = intent.charges.data.first
          raise('charge not succeeded') unless charge.status == 'succeeded'

          card = charge.payment_method_details.try(:card) || {}
          active_card = "**** **** **** #{card['last4']} #{card['brand']} #{card['exp_month']}/#{card['exp_year']}" if card.present?

          {
            charge_id: charge.id,
            payment_method_id: charge.payment_method,
            payment_intent_id: intent.id,

            active_card: active_card,
            card: card['brand'],

            amount: charge.amount,
            created: charge.created,
            currency: charge.currency,
            customer: charge.customer,
            status: charge.status
          }.compact

        rescue => e
          e.message
        end
      end

    end
  end
end
