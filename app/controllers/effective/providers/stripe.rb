module Effective
  module Providers
    module Stripe
      extend ActiveSupport::Concern

      def stripe
        @order = Order.find(params[:id])

        EffectiveOrders.authorize!(self, :update, @order)

        payment = validate_stripe_payment(stripe_params[:payment_intent_id])

        if payment.blank? || !payment.kind_of?(Hash)
          return order_declined(payment: payment, provider: 'stripe', declined_url: stripe_params[:declined_url])
        end

        order_purchased(
          payment: payment,
          provider: 'stripe',
          card: payment[:card],
          purchased_url: stripe_params[:purchased_url],
          declined_url: stripe_params[:declined_url]
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

          {
            payment_intent_id: intent.id,
            payment_method: intent.payment_method,

            charge_id: charge.id,
            amount: charge.amount,
            created: charge.created,
            currency: charge.currency,
            customer: charge.customer,
            description: charge.customer,
            status: charge.status,

            card: card['brand'],
            exp_month: card['exp_month'],
            exp_year: card['exp_year'],
            last4: card['last4']
          }
        rescue => e
          e.message
        end
      end

    end
  end
end
