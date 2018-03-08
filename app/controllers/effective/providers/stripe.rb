module Effective
  module Providers
    module Stripe
      extend ActiveSupport::Concern

      # TODO: Make stripe charge work with admin checkout workflow, purchased_url and declined_url
      # Make it save the customer and not require typing in a CC every time.

      def stripe_charge
        @order ||= Effective::Order.find(stripe_charge_params[:effective_order_id])
        @stripe_charge = Effective::Providers::StripeCharge.new(stripe_charge_params)
        @stripe_charge.order = @order

        EffectiveOrders.authorize!(self, :update, @order)

        if @stripe_charge.valid? && (response = process_stripe_charge(@stripe_charge)) != false
          order_purchased(
            details: response,
            provider: 'stripe',
            card: (response[:charge]['source']['brand'] rescue nil)
          )
        else
          @page_title = 'Checkout'
          flash.now[:danger] = @stripe_charge.errors.full_messages.to_sentence
          render :show
        end
      end

      private

      def process_stripe_charge(charge)
        Effective::Order.transaction do
          begin
            subscripter = Effective::Subscripter.new(user: charge.order.user, stripe_token: charge.stripe_token)
            subscripter.save!

            return charge_with_stripe(charge, subscripter.customer)
          rescue => e
            charge.errors.add(:base, "Unable to process order with Stripe. Your credit card has not been charged. Message: \"#{e.message}\".")
            raise ActiveRecord::Rollback
          end
        end

        false
      end

      def charge_with_stripe(charge, customer)
        results = { charge: nil }

        if charge.order.total > 0
          results[:charge] = JSON.parse(::Stripe::Charge.create(
            amount: charge.order.total,
            currency: EffectiveOrders.stripe[:currency],
            customer: customer.stripe_customer.id,
            description: "Charge for Order ##{charge.order.to_param}"
          ).to_json)
        end

        results
      end

      # StrongParameters
      def stripe_charge_params
        params.require(:effective_providers_stripe_charge).permit(:stripe_token, :effective_order_id)
      end

    end
  end
end
