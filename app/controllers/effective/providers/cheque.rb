module Effective
  module Providers
    module Cheque
      extend ActiveSupport::Concern

      def pay_by_cheque
        @order ||= Order.find(params[:id])
        @page_title = 'Payment Required'

        EffectiveOrders.authorized?(self, :update, @order)

        @order.purchase_state = EffectiveOrders::PENDING
        @order.payment_provider = 'cheque'

        begin
          @order.save!
          @order.send_pending_order_invoice_to_buyer!

          Effective::Cart.where(user_id: @order.user_id).destroy_all

          message = "Successfully indicated order will be payed by cheque. A pending order invoice has been sent to #{@order.user.email}"

          # When posted from admin form, there will be a redirect url
          if params[:purchased_url].present?
            flash[:success] = message
            redirect_to params[:purchased_url].gsub(':id', @order.to_param.to_s)
          else
            # Otherwise this is the user flow
            flash.now[:success] = message
            render 'effective/orders/cheque/pay_by_cheque'
          end
        rescue => e
          flash[:danger] = "Unable to save your order: #{@order.errors.full_messages.to_sentence}. Please try again."
          redirect_to params[:declined_url].presence || effective_orders.order_path(@order)
        end
      end
    end
  end
end
