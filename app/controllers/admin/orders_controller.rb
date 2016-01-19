module Admin
  class OrdersController < ApplicationController
    before_filter :authenticate_user!   # This is devise, ensure we're logged in.

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_orders] : EffectiveOrders.layout)

    def index
      @datatable = Effective::Datatables::Orders.new() if defined?(EffectiveDatatables)
      @page_title = 'Orders'

      authorize_effective_order!
    end

    def show
      @order = Effective::Order.find(params[:id])
      @page_title = "Order ##{@order.to_param}"

      authorize_effective_order!
    end

    def new
      @order = Effective::Order.new
      @page_title = 'New Order'

      authorize_effective_order!
    end

    def create
      @user = User.find_by_id(order_params[:user_id])
      @order = Effective::Order.new({}, @user)
      @order.send_payment_request_to_buyer = order_params[:send_payment_request_to_buyer]

      authorize_effective_order!

      if order_params[:order_items_attributes].present?
        order_params[:order_items_attributes].each do |_, item_attrs|
          purchasable = Effective::Product.new(item_attrs[:purchasable_attributes])
          @order.add(purchasable, item_attrs[:quantity].to_i)
        end
      end

      if @order.create_as_pending
        path_for_redirect = params[:commit] == 'Save and Add New' ? effective_orders.new_admin_order_path : effective_orders.admin_orders_path
        flash[:success] = 'Successfully created order'
        redirect_to path_for_redirect
      else
        @page_title = 'New Order'
        flash.now[:danger] = 'Unable to create order'
        render :new
      end
    end

    def mark_as_paid
      @order = Effective::Order.find(params[:id])
      authorize_effective_order!

      if @order.purchase!('Marked as paid by admin', email: EffectiveOrders.mailer[:send_order_receipts_when_marked_paid_by_admin])
        flash[:success] = 'Order marked as paid successfully'
        redirect_to effective_orders.admin_orders_path
      else
        flash[:danger] = 'Unable to mark order as paid'
        request.referrer ? (redirect_to :back) : (redirect_to effective_orders.admin_orders_path)
      end
    end

    def send_payment_request
      @order = Effective::Order.find(params[:id])
      authorize_effective_order!

      if @order.send_payment_request_to_buyer!
        flash[:success] = "Successfully sent payment request to #{@order.user.email}"
      else
        flash[:danger] = 'Unable to send payment request'
      end

      request.referrer ? (redirect_to :back) : (redirect_to effective_orders.admin_order_path(@order))
    end

    private

    def order_params
      params.require(:effective_order).permit(:user_id, :send_payment_request_to_buyer,
        order_items_attributes: [
          :quantity, :_destroy, purchasable_attributes: [
            :title, :price, :tax_exempt
          ]
        ]
      )
    end

    def authorize_effective_order!
      EffectiveOrders.authorized?(self, :admin, :effective_orders)
      EffectiveOrders.authorized?(self, action_name.to_sym, @order || Effective::Order)
    end

  end
end
