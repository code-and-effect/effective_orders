module Effective
  module Providers
    module Cheque
      extend ActiveSupport::Concern

      def pay_by_cheque
        @order ||= Order.find(params[:id])
        EffectiveOrders.authorized?(self, :update, @order)

        @order.purchase_state = EffectiveOrders::PENDING
        @order.payment_provider = 'cheque'

        @page_title = 'Payment required'

        if @order.save
          current_cart.try(:destroy)
          flash[:success] = 'Successfully marked order as pending.  Please send a cheque.'
        else
          flash[:danger] = "Unable to save your order: #{@order.errors.full_messages.to_sentence}. Please try again."
        end

        render 'effective/orders/cheque/pay_by_cheque'
      end
    end
  end
end
