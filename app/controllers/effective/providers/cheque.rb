module Effective
  module Providers
    module Cheque
      extend ActiveSupport::Concern

      def pay_by_cheque
        @order ||= Order.find(params[:id])

        @order.purchase_state = EffectiveOrders::PENDING
        @order.payment_provider = 'cheque'

        EffectiveOrders.authorized?(self, :update, @order)

        @page_title = 'Payment Required'

        if @order.save
          @order.send_pending_order_invoice_to_buyer!
          current_cart.try(:destroy)
          flash.now[:success] = 'Successfully indicated order will be payed by cheque.'
        else
          flash[:danger] = "Unable to save your order: #{@order.errors.full_messages.to_sentence}. Please try again."
          redirect_to effective_orders.order_path(@order)
          return
        end

        render 'effective/orders/cheque/pay_by_cheque'
      end
    end
  end
end
