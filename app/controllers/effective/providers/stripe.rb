require 'stripe'

module Effective
  module Providers
    module Stripe
      extend ActiveSupport::Concern

      included do
      end

      def stripe_charge  # This is a create action
        @order = Effective::Order.find(stripe_charge_params[:effective_order_id])
        @stripe_charge = Effective::StripeCharge.new(stripe_charge_params)
        @stripe_charge.order = @order

        EffectiveOrders.authorized?(self, :create, @order)

        if @stripe_charge.save && (response = process_stripe_charge(@stripe_charge)) != false
          order_purchased(response.try(:to_hash) || 'purchased via Stripe') # orders_controller#order_purchased
        else
          @order.customer.reload
          render :action => :create
        end
      end

      private

      def process_stripe_charge(charge)
        ::Stripe.api_key = EffectiveOrders.stripe[:secret_key]

        amount = (charge.order.total * 100.0).to_i # A positive integer in cents representing how much to charge the card. The minimum amount is 50 cents.

        Effective::Order.transaction do
          begin
            stripe_customer = find_or_create_stripe_customer(charge.order.customer, charge.token)

            return ::Stripe::Charge.create(:amount => amount, :currency => EffectiveOrders.stripe[:currency], :customer => stripe_customer.id, :card => stripe_customer.default_card)
          rescue => e
            charge.errors.add(:base, "Unable to checkout order with Stripe.  Your credit card has not been charged.  Message: \"#{e.message}\".")
            raise ActiveRecord::Rollback
          end
        end

        false
      end

      def find_or_create_stripe_customer(customer, token)
        stripe_customer = (
          if customer.stripe_customer.present?
            ::Stripe::Customer.retrieve(customer.stripe_customer)
          else
            ::Stripe::Customer.create(:email => customer.user.email, :description => customer.user.id.to_s)
          end
        )

        if token.present? # Oh, so they want to use a new credit card...
          stripe_customer.card = token  # This sets the default_card to the new card

          if stripe_customer.save && stripe_customer.default_card.present?
            card = stripe_customer.cards.retrieve(stripe_customer.default_card)

            customer.stripe_customer = stripe_customer.id
            customer.stripe_active_card = "**** **** **** #{card.last4} #{card.type} #{card.exp_month}/#{card.exp_year}"
            customer.save!
          else
            raise Exception.new('unable to update stripe customer with new card')
          end
        end

        stripe_customer
      end

      # StrongParameters
      def stripe_charge_params
        begin
          params.require(:effective_stripe_charge).permit(:token, :effective_order_id)
        rescue => e
          params[:effective_stripe_charge]
        end
      end

    end
  end
end
