module Admin
  class OrdersController < ApplicationController
    before_filter :authenticate_user!   # This is devise, ensure we're logged in.

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_orders] : EffectiveOrders.layout)

    def index
      @datatable = Effective::Datatables::Orders.new() if defined?(EffectiveDatatables)
      @page_title = 'Orders'

      authorize_action_upon_order(Effective::Order)
    end

    def show
      @order = Effective::Order.find(params[:id])
      @page_title = "Order ##{@order.to_param}"

      authorize_action_upon_order
    end

    def new
      @order = Effective::Order.new
      @page_title = 'New Order'

      authorize_action_upon_order

      assign_users
    end

    def create
      @user = User.find_by_id(order_params[:user_id])
      @order = Effective::Order.new({}, @user)
      @order.purchase_state = EffectiveOrders::PENDING

      authorize_action_upon_order

      if order_params[:order_items_attributes].present?
        order_params[:order_items_attributes].each do |_, item_attrs|
          purchasable = Effective::Product.new(item_attrs[:purchasable_attributes])
          @order.add(purchasable, item_attrs[:quantity].to_i)
        end
      end

      if @order.save
        path_for_redirect = params[:commit] == 'Save and Add New' ? effective_orders.new_admin_order_path : effective_orders.admin_orders_path
        flash[:success] = 'Successfully created custom order'
        redirect_to path_for_redirect
      else
        @page_title = 'New Order'
        assign_users
        flash[:danger] = 'Unable to create custom order'
        render :new
      end
    end

    def mark_as_paid
      @order = Effective::Order.find(params[:id])
      authorize_action_upon_order

      if @order.purchase!('Paid by cheque', email: EffectiveOrders.mailer[:send_order_receipt_to_buyer_when_marked_paid])
        flash[:success] = 'Order marked as paid successfully'
        redirect_to effective_orders.admin_orders_path
      else
        flash[:danger] = 'Unable to mark order as paid'
        redirect_to :back
      end
    end

    def send_payment_request
      @order = Effective::Order.find(params[:id])
      authorize_action_upon_order

      if @order.send_payment_request_to_buyer!
        flash[:success] = "Successfully sent payment request to #{@order.user.email}"
      else
        flash[:danger] = 'Unable to send payment request'
      end

      redirect_to(request.referrer.present? ? :back : effective_orders.admin_order_path(@order))
    end

    private

    def order_params
      params.require(:effective_order).permit(
        :user_id,
        order_items_attributes: [
          :quantity, purchasable_attributes: [
            :description, :price, :tax_exempt
          ]
        ]
      )
    end

    def authorize_action_upon_order(order = @order)
      EffectiveOrders.authorized?(self, :admin, :effective_orders)
      EffectiveOrders.authorized?(self, action_name.to_sym, order)
    end

    def assign_users
      @users = User.all.sort { |user1, user2| user1.to_s <=> user2.to_s }
    end
  end
end
