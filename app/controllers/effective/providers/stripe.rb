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
          order_purchased(response) # orders_controller#order_purchased
        else
          @order.buyer.reload
          render :action => :create
        end
      end

      private

      def process_stripe_charge(charge)
        ::Stripe.api_key = EffectiveOrders.stripe[:secret_key]

        Effective::Order.transaction do
          begin
            buyer = find_or_create_stripe_customer(charge.order.buyer, charge.token)

            if EffectiveOrders.stripe_connect_enabled
              # Go through and create Stripe::Tokens for each seller
              items = charge.order.order_items.group_by(&:seller)
              results = {}

              # We do all these Tokens first, so if one throws an exception no charges are made
              items.each do |seller, _|
                seller.token = ::Stripe::Token.create({:customer => buyer.id}, seller.stripe_connect_access_token)
              end

              # Make one charge per seller, for all his order_items
              items.each do |seller, order_items|
                amount = (order_items.sum(&:total) * 100.0).to_i
                description = "Charge for Order ##{charge.order.id} with OrderItems #{order_items.map(&:id).join(', ')}"
                application_fee = (order_items.sum(&:stripe_connect_application_fee) * 100.0).to_i

                results[seller.id] = JSON.parse(::Stripe::Charge.create(
                  :amount => amount, 
                  :currency => EffectiveOrders.stripe[:currency], 
                  :card => seller.token.id, 
                  :description => description,
                  :application_fee => application_fee
                ).to_json)
              end

              return results
            else
              # This is a regular Stripe Charge for the full amount of the order

              amount = (charge.order.total * 100.0).to_i # A positive integer in cents representing how much to charge the card. The minimum amount is 50 cents.
              description = "Charge for Order ##{charge.order.id}"

              return JSON.parse(::Stripe::Charge.create(
                  :amount => amount, 
                  :currency => EffectiveOrders.stripe[:currency], 
                  :customer => buyer.id, 
                  :card => buyer.default_card, 
                  :description => description
                ).to_json)
            end
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
