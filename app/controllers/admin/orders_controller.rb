module Admin
  class OrdersController < ApplicationController
    before_filter :authenticate_user!   # This is devise, ensure we're logged in.

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_orders] : EffectiveOrders.layout)

    def index
      @datatable = Effective::Datatables::Orders.new() if defined?(EffectiveDatatables)
      @page_title = 'Orders'

      EffectiveOrders.authorized?(self, :admin, :effective_orders)
      EffectiveOrders.authorized?(self, :index, Effective::Order)
    end

    def show
      @order = Effective::Order.find(params[:id])
      @page_title = "Order ##{@order.to_param}"

      EffectiveOrders.authorized?(self, :show, @order)
    end

    def new
      @order = Effective::Order.new
      @page_title = 'New Order'

      EffectiveOrders.authorized?(self, :new, @order)
    end

    def create
      @user = User.find_by_id(order_params[:user_id])
      @order = Effective::Order.new({}, @user)
      @order.assign_attributes(custom: true, purchase_state: EffectiveOrders::PENDING)

      EffectiveOrders.authorized?(self, :create, @order)

      if order_params[:order_items_attributes].present?
        order_params[:order_items_attributes].each do |_, item_attrs|
          purchasable = Effective::CustomProduct.new(item_attrs[:purchasable_attributes])
          purchasable.tax_exempt = ::ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include?(item_attrs[:tax_exempt])
          @order.add(purchasable, item_attrs[:quantity].to_i)
        end
      end

      if @order.save
        path_for_redirect = params[:commit] == 'Save and Add New' ? effective_orders.new_admin_order_path : effective_orders.admin_orders_path
        flash.now[:success] = 'Successfully created custom order'
        redirect_to path_for_redirect
      else
        @page_title = 'New Order'
        flash.now[:danger] = 'Unable to create custom order'
        render :new
      end
    end

    def mark_as_paid
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :mark_as_paid, @order)

      if @order.purchase!('Paid by invoice', email: false)
        flash.now[:success] = 'Order marked as paid successfully.'
        redirect_to effective_orders.admin_orders_path
      else
        flash.now[:danger] = 'Unable to mark order as paid.'
        redirect_to :back
      end
    end

    def send_buyer_invoice
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)

      if @order.send_custom_order_invoice_to_buyer!
        flash[:success] = "Successfully sent order invoice to #{@order.user.email}"
      else
        flash[:danger] = 'Unable to send order invoice'
      end

      redirect_to(request.referrer.present? ? :back : effective_orders.admin_order_path(@order))
    end

    private

    def order_params
      params.require(:effective_order).permit(
        :user_id,
        order_items_attributes: [
          :quantity, :tax_exempt,
          purchasable_attributes: [:description, :price]
        ]
      )
    end
  end
end
