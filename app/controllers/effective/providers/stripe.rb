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

        if @stripe_charge.valid? && (response = process_stripe_charge(@stripe_charge)) != false
          order_purchased(response) # orders_controller#order_purchased
        else
          flash[:error] = @stripe_charge.errors.full_messages.join(',')
          render :action => :create
        end
      end

      private

      def process_stripe_charge(charge)
        Effective::Order.transaction do
          begin
            buyer = Customer.for_user(charge.order.user)
            buyer.update_card!(charge.token)

            if EffectiveOrders.stripe_connect_enabled
              # Go through and create Stripe::Tokens for each seller
              items = charge.order.order_items.group_by(&:seller)
              results = {}

              # We do all these Tokens first, so if one throws an exception no charges are made
              items.each do |seller, _|
                seller.token = ::Stripe::Token.create({:customer => buyer.stripe_customer.id}, seller.stripe_connect_access_token)
              end

              # Make one charge per seller, for all his order_items
              items.each do |seller, order_items|
                amount = (order_items.sum(&:total) * 100.0).to_i
                description = "Charge for Order ##{charge.order.id} with OrderItems ##{order_items.map(&:id).join(', #')}"
                application_fee = (order_items.sum(&:stripe_connect_application_fee) * 100.0).to_i

                results[seller.id] = JSON.parse(::Stripe::Charge.create(
                  {
                    :amount => amount, 
                    :currency => EffectiveOrders.stripe[:currency], 
                    :card => seller.token.id,
                    :description => description,
                    :application_fee => application_fee
                  }, 
                  seller.stripe_connect_access_token
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
                  :customer => buyer.stripe_customer.id, 
                  :description => description
                ).to_json)
            end
          rescue => e
            charge.errors.add(:base, "Unable to process order with Stripe.  Your credit card has not been charged.  Message: \"#{e.message}\".")
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
