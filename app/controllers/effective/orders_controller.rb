module Effective
  class OrdersController < ApplicationController
    include Concerns::Purchase

    include Providers::Cheque if EffectiveOrders.cheque?
    include Providers::Free if EffectiveOrders.free?
    include Providers::MarkAsPaid if EffectiveOrders.mark_as_paid?
    include Providers::Moneris if EffectiveOrders.moneris?
    include Providers::Paypal if EffectiveOrders.paypal?
    include Providers::Pretend if EffectiveOrders.pretend?
    include Providers::Refund if EffectiveOrders.refund?
    include Providers::Stripe if EffectiveOrders.stripe?

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:orders] : EffectiveOrders.layout)

    before_action :authenticate_user!, except: [:ccbill_postback, :free, :paypal_postback, :moneris_postback, :pretend]
    before_action :set_page_title, except: [:show]

    # If you want to use the Add to Cart -> Checkout flow
    # Add one or more items however you do.
    # redirect_to effective_orders.new_order_path, which is here.
    # This is the entry point for any Checkout button.
    # It displayes an order based on the cart
    # Always step1
    def new
      @order ||= Effective::Order.new(view_context.current_cart)

      EffectiveOrders.authorize!(self, :new, @order)

      unless @order.valid?
        flash[:danger] = "Unable to proceed: #{flash_errors(@order)}. Please try again."
        redirect_to(effective_orders.cart_path)
        return
      end
    end

    # Confirms an order from the cart.
    def create
      @order ||= Effective::Order.new(view_context.current_cart)
      EffectiveOrders.authorize!(self, :create, @order)

      @order.assign_attributes(checkout_params)

      if (@order.confirm! rescue false)
        redirect_to(effective_orders.order_path(@order))
      else
        flash.now[:danger] = "Unable to proceed: #{flash_errors(@order)}. Please try again."
        render :new
      end
    end

    # If you want to use the order = Effective::Order.new(@thing); order.save! flow
    # Add one or more items to the order.
    # redirect_to effective_orders.order_path(order), which is here
    # This is the entry point for an existing order.
    # Might render step1 or step2
    def show
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorize!(self, :show, @order)

      @page_title ||= ((@order.user == current_user && !@order.purchased?) ? 'Checkout' : @order.to_s)
    end

    # Always step1
    def edit
      @order ||= Effective::Order.find(params[:id])
      EffectiveOrders.authorize!(self, :edit, @order)
    end

    # Confirms the order from existing order
    def update
      @order ||= Effective::Order.find(params[:id])
      EffectiveOrders.authorize!(self, :update, @order)

      @order.assign_attributes(checkout_params)

      if (@order.confirm! rescue false)
        redirect_to(effective_orders.order_path(@order))
      else
        flash.now[:danger] = "Unable to proceed: #{flash_errors(@order)}. Please try again."
        render :edit
      end
    end

    # My Orders History
    def index
      @orders = Effective::Order.deep.purchased.where(user: current_user)
      @pending_orders = Effective::Order.deep.pending.where(user: current_user)

      EffectiveOrders.authorize!(self, :index, Effective::Order.new(user: current_user))
    end

    # Thank you for Purchasing this Order. This is where a successfully purchased order ends up
    def purchased # Thank You!
      @order = if params[:id].present?
        Effective::Order.find(params[:id])
      elsif current_user.present?
        Effective::Order.sorted.purchased_by(current_user).last
      end

      if @order.blank?
        redirect_to(effective_orders.orders_path) and return
      end

      EffectiveOrders.authorize!(self, :show, @order)

      redirect_to(effective_orders.order_path(@order)) unless @order.purchased?
    end

    def declined
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorize!(self, :show, @order)

      redirect_to(effective_orders.order_path(@order)) unless @order.declined?
    end

    def send_buyer_receipt
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorize!(self, :show, @order)

      if @order.send_order_receipt_to_buyer!
        flash[:success] = "A receipt has been sent to #{@order.user.email}"
      else
        flash[:danger] = "Unable to send receipt."
      end

      if respond_to?(:redirect_back)
        redirect_back(fallback_location: effective_orders.order_path(@order))
      elsif request.referrer.present?
        redirect_to :back
      else
        redirect_to effective_orders.order_path(@order)
      end
    end

    def bulk_send_buyer_receipt
      @orders = Effective::Order.purchased.where(id: params[:ids])

      begin
        EffectiveOrders.authorize!(self, :index, Effective::Order.new(user: current_user))

        @orders.each do |order|
          next unless EffectiveOrders.authorized?(self, :show, order)

          order.send_order_receipt_to_buyer!
        end

        render json: { status: 200, message: "Successfully sent #{@orders.length} receipt emails"}
      rescue => e
        render json: { status: 500, message: "Bulk send buyer receipt error: #{e.message}" }
      end
    end

    private

    # StrongParameters
    def checkout_params
      params.require(:effective_order).permit(EffectiveOrders.permitted_params)
    end

    def set_page_title
      @page_title ||= case params[:action]
        when 'index'        ; 'Order History'
        when 'purchased'    ; 'Thank You'
        when 'declined'     ; 'Payment Declined'
        else 'Checkout'
      end
    end

  end
end
