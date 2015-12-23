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
  end
end
