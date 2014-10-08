module Admin
  class OrdersController < ApplicationController
    before_filter :authenticate_user!   # This is devise, ensure we're logged in.

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_orders] : EffectiveOrders.layout)

    def index
      @datatable = Effective::Datatables::Orders.new() if defined?(EffectiveDatatables)
      @page_title = 'Orders'

      EffectiveOrders.authorized?(self, :index, Effective::Order)
    end

    def show
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)
    end

    def resend_buyer_receipt
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)

      if (Effective::OrdersMailer.order_receipt_to_buyer(@order).deliver rescue false)
        flash[:success] = "Successfully resent order receipt to #{@order.user.email}"
      else
        flash[:danger] = "Unable to send order receipt"
      end

      begin
        redirect_to :back
      rescue => e
        redirect_to effective_orders.admin_orders_path
      end

    end

  end
end
