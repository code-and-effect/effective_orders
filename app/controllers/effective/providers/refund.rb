module Effective
  module Providers
    module Refund
      extend ActiveSupport::Concern

      def refund
        @order ||= Order.find(params[:id])

        EffectiveOrders.authorize!(self, :update, @order)
        EffectiveOrders.authorize!(self, :admin, :effective_orders)

        unless @order.refund?
          flash[:danger] = 'Unable to process refund with a non-negative total'
          redirect_to effective_orders.admin_order_path(@order)
          return
        end

        @order.assign_attributes(refund_params.except(:payment, :payment_provider, :payment_card))

        order_purchased(
          details: refund_params[:payment],
          provider: refund_params[:payment_provider],
          card: refund_params[:payment_card],
          email: @order.send_mark_as_paid_email_to_buyer?,
          skip_buyer_validations: true,
          purchased_url: params[:purchased_url].presence || effective_orders.admin_order_path(@order),
          declined_url: params[:declined_url].presence || effective_orders.admin_order_path(@order)
        )
      end

      def refund_params
        params.require(:effective_order).permit(
          :payment, :payment_provider, :payment_card, :note_to_buyer, :send_mark_as_paid_email_to_buyer
        )
      end

    end
  end
end
