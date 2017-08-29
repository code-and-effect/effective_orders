module Effective
  module Providers
    module MarkAsPaid
      extend ActiveSupport::Concern

      def mark_as_paid
        @order ||= Order.find(params[:id])

        EffectiveOrders.authorized?(self, :update, @order)
        EffectiveOrders.authorized?(self, :admin, :effective_orders)

        @order.assign_attributes(mark_as_paid_params.except(:payment, :payment_provider, :payment_card))

        order_purchased(
          details: mark_as_paid_params[:payment],
          provider: mark_as_paid_params[:payment_provider],
          card: mark_as_paid_params[:payment_card],
          email: @order.send_mark_as_paid_email_to_buyer?,
          skip_buyer_validations: true,
          purchased_url: params[:purchased_url],
          declined_url: params[:declined_url]
        )
      end

      def mark_as_paid_params
        params.require(:effective_order).permit(
          :payment, :payment_provider, :payment_card, :note_to_buyer, :send_mark_as_paid_email_to_buyer
        )
      end

    end
  end
end
