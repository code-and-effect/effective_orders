module Effective
  module Providers
    module DeluxeDelayedPurchase
      extend ActiveSupport::Concern

      # Admin action
      def deluxe_delayed_purchase
        raise('deluxe_delayed_purchase provider is not available') unless EffectiveOrders.deluxe_delayed?

        @order ||= Order.deep.find(params[:id])

        EffectiveResources.authorize!(self, :update, @order)
        EffectiveResources.authorize!(self, :admin, :effective_orders)

        raise('expected a delayed? and deferred? order') unless @order.delayed? && @order.deferred?

        ## Purchase Order right now
        api = Effective::DeluxeApi.new

        purchased = api.purchase!(@order, @order.delayed_payment_intent)
        payment = api.payment

        if purchased == false
          flash[:danger] = "Payment was unsuccessful. The credit card payment failed with message: #{Array(payment['responseMessage']).to_sentence.presence || 'none'}. Please try again."
          return order_declined(payment: payment, provider: 'deluxe_delayed', card: payment['card'], declined_url: deluxe_delayed_purchase_params[:declined_url])
        end

        @order.assign_attributes(deluxe_delayed_purchase_params.except(:purchased_url, :declined_url, :id))

        order_purchased(
          payment: payment,
          provider: 'deluxe_delayed',
          card: payment['card'],
          email: @order.send_mark_as_paid_email_to_buyer?,
          skip_buyer_validations: true,
          purchased_url: effective_orders.admin_order_path(@order),
          current_user: nil # Admin action, we don't want to assign current_user to the order
        )
      end

      def deluxe_delayed_purchase_params
        params.require(:effective_order).permit(
          :id, :note_to_buyer, :note_internal, :send_mark_as_paid_email_to_buyer,
          :purchased_url, :declined_url
        )
      end

    end
  end
end
