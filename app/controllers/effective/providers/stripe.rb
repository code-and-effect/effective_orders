require 'stripe'

module Effective
  module Providers
    module Stripe
      extend ActiveSupport::Concern

      included do
      end

      def stripe_charge  # This is a create action
        @order = Effective::Order.find(stripe_charge_params[:effective_order_id])
        @stripe_charge = Effective::StripeCharge.new(params[:effective_stripe_charge])
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

        user = @stripe_charge.order.user
        customer = @stripe_charge.order.customer
        token = @stripe_charge.token
        amount = (@stripe_charge.order.total * 100.0).to_i # A positive integer in cents representing how much to charge the card. The minimum amount is 50 cents.

        Effective::Order.transaction do
          begin
            if token.present? # New Credit Card
              stripe_customer = ::Stripe::Customer.create(:card => token, :email => user.email, :description => "Order #{@stripe_charge.order.id}")
              customer.stripe_customer = stripe_customer.id
              card = stripe_customer.cards.retrieve(stripe_customer.default_card)
              customer.stripe_active_card = "**** **** **** #{card.last4} #{card.type} #{card.exp_month}/#{card.exp_year}"
              customer.save!
            end

            # This will raise an Exception if it doesn't successfully charge.
            return ::Stripe::Charge.create(:amount => amount, :currency => EffectiveOrders.stripe[:currency], :customer => customer.stripe_customer)
          rescue => e
            @stripe_charge.errors.add(:base, "Unable to checkout order with Stripe.  Your credit card has not been charged.  Message: \"#{e.message}\".")
            raise ActiveRecord::Rollback
          end
        end

        false
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
