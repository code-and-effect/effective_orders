module Effective
  class OrdersController < ApplicationController
    include EffectiveCartsHelper

    include Concerns::Purchase

    include Providers::AppCheckout if EffectiveOrders.app_checkout_enabled
    include Providers::Ccbill if EffectiveOrders.ccbill_enabled
    include Providers::Cheque if EffectiveOrders.cheque_enabled
    include Providers::Free if EffectiveOrders.allow_free_orders
    include Providers::MarkAsPaid if EffectiveOrders.mark_as_paid_enabled
    include Providers::Moneris if EffectiveOrders.moneris_enabled
    include Providers::Paypal if EffectiveOrders.paypal_enabled
    include Providers::Pretend if EffectiveOrders.allow_pretend_purchase_in_development && !Rails.env.production?
    include Providers::Pretend if EffectiveOrders.allow_pretend_purchase_in_production && Rails.env.production?
    include Providers::Refund if EffectiveOrders.allow_refunds
    include Providers::Stripe if EffectiveOrders.stripe_enabled
    include Providers::StripeConnect if EffectiveOrders.stripe_connect_enabled

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:orders] : EffectiveOrders.layout)

    before_action :authenticate_user!, except: [:ccbill_postback, :free, :paypal_postback, :pretend]
    before_action :set_page_title, except: [:show]

    # This is the entry point for any Checkout button
    def new
      @order ||= Effective::Order.new(current_cart, user: current_user)

      EffectiveOrders.authorize!(self, :new, @order)

      # We're only going to check for a subset of errors on this step,
      # with the idea that we don't want to create an Order object if the Order is totally invalid
      @order.valid?

      if @order.errors[:order_items].present?
        flash[:danger] = @order.errors[:order_items].first
        redirect_to(effective_orders.cart_path)
        return
      elsif @order.errors[:total].present?
        flash[:danger] = @order.errors[:total].first
        redirect_to(effective_orders.cart_path)
        return
      end

      @order.errors.clear
      @order.billing_address.errors.clear if @order.billing_address
      @order.shipping_address.errors.clear if @order.shipping_address
    end

    def create
      @order ||= Effective::Order.new(current_cart, user: current_user)
      EffectiveOrders.authorize!(self, :create, @order)

      @order.assign_attributes(checkout_params) if params[:effective_order]

      Effective::Order.transaction do
        begin
          @order.save!
          redirect_to(effective_orders.order_path(@order)) and return
        rescue => e
          raise ActiveRecord::Rollback
        end
      end

      flash.now[:danger] = "Unable to proceed: #{@order.errors.full_messages.to_sentence}. Please try again."
      render :new
    end

    def edit
      @order ||= Effective::Order.find(params[:id])
      EffectiveOrders.authorize!(self, :edit, @order)
    end

    def update
      @order ||= Effective::Order.find(params[:id])
      EffectiveOrders.authorize!(self, :update, @order)

      @order.assign_attributes(checkout_params)

      Effective::Order.transaction do
        begin
          @order.save!
          redirect_to(effective_orders.order_path(@order)) and return
        rescue => e
          raise ActiveRecord::Rollback
        end
      end

      flash.now[:danger] = "Unable to proceed: #{@order.errors.full_messages.to_sentence}. Please try again."
      render :edit
    end

    def show
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorize!(self, :show, @order)

      @page_title ||= ((@order.user == current_user && !@order.purchased?) ? 'Checkout' : @order.to_s)
    end

    def index
      @orders = Effective::Order.deep.purchased_by(current_user)
      @pending_orders = Effective::Order.deep.pending.where(user: current_user)

      EffectiveOrders.authorize!(self, :index, Effective::Order.new(user: current_user))
    end

    # Basically an index page.
    # Purchases is an Order History page.  List of purchased orders
    def my_purchases
      @orders = Effective::Order.deep.purchased_by(current_user)
      EffectiveOrders.authorize!(self, :index, Effective::Order.new(user: current_user))
    end

    # Sales is a list of what products beign sold by me have been purchased
    def my_sales
      @order_items = Effective::OrderItem.deep.sold_by(current_user)
      EffectiveOrders.authorize!(self, :index, Effective::Order.new(user: current_user))
    end

    # Thank you for Purchasing this Order. This is where a successfully purchased order ends up
    def purchased # Thank You!
      @order = if params[:id].present?
        Effective::Order.find(params[:id])
      elsif current_user.present?
        Effective::Order.purchased_by(current_user).first
      end

      if @order.blank?
        redirect_to(effective_orders.my_purchases_orders_path) and return
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
          next unless (EffectiveOrders.authorize!(self, :show, order) rescue false)

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
        when 'index'        ; 'Orders'
        when 'my_purchases' ; 'Order History'
        when 'my_sales'     ; 'Sales History'
        when 'purchased'    ; 'Thank You'
        when 'declined'     ; 'Payment Declined'
        else 'Checkout'
      end
    end

  end
end
