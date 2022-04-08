module Effective
  module Providers
    module MarkAsPaid
      extend ActiveSupport::Concern

      def mark_as_paid
        raise('mark_as_paid provider is not available') unless EffectiveOrders.mark_as_paid?

        @order ||= Order.find(params[:id])

        EffectiveResources.authorize!(self, :update, @order)
        EffectiveResources.authorize!(self, :admin, :effective_orders)

        @order.assign_attributes(mark_as_paid_params.except(:payment_provider, :payment_card))

        order_purchased(
          payment: 'mark as paid',
          provider: mark_as_paid_params[:payment_provider],
          card: mark_as_paid_params[:payment_card],
          email: @order.send_mark_as_paid_email_to_buyer?,
          skip_buyer_validations: true,
          purchased_url: effective_orders.admin_order_path(@order)
        )
      end

      def mark_as_paid_params
        params.require(:effective_order).permit(
          :purchased_at, :payment_provider, :payment_card,
          :note_to_buyer, :note_internal, :send_mark_as_paid_email_to_buyer
        )
      end

    end
  end
end
