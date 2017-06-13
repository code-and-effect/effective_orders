module Effective
  class OrdersController < ApplicationController
    include EffectiveCartsHelper

    include Providers::AppCheckout if EffectiveOrders.app_checkout_enabled
    include Providers::Ccbill if EffectiveOrders.ccbill_enabled
    include Providers::Cheque if EffectiveOrders.cheque_enabled
    include Providers::Free if EffectiveOrders.allow_free_orders
    include Providers::MarkAsPaid if EffectiveOrders.mark_as_paid_enabled
    include Providers::Moneris if EffectiveOrders.moneris_enabled
    include Providers::Paypal if EffectiveOrders.paypal_enabled
    include Providers::Pretend if EffectiveOrders.allow_pretend_purchase_in_development && !Rails.env.production?
    include Providers::Pretend if EffectiveOrders.allow_pretend_purchase_in_production && Rails.env.production?
    include Providers::Stripe if EffectiveOrders.stripe_enabled
    include Providers::StripeConnect if EffectiveOrders.stripe_connect_enabled

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:orders] : EffectiveOrders.layout)

    before_action :authenticate_user!, except: [:paypal_postback, :ccbill_postback]
    before_action :set_page_title, except: [:show]

    # This is the entry point for any Checkout button
    def new
      @order ||= Effective::Order.new(current_cart, user: current_user)

      EffectiveOrders.authorized?(self, :new, @order)

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
      @order.billing_address.try(:errors).try(:clear)
      @order.shipping_address.try(:errors).try(:clear)
    end

    def create
      @order ||= Effective::Order.new(current_cart, user: current_user)
      EffectiveOrders.authorized?(self, :create, @order)

      if @order.update_attributes(checkout_params)
        redirect_to effective_orders.order_path(@order)
      else
        flash.now[:danger] = "Unable to save order: #{@order.errors.full_messages.to_sentence}. Please try again."
        render :new
      end
    end

    def edit
      @order ||= Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :edit, @order)
    end

    # If there is an existing order, it will be posted to the /update action, instead of /create
    def update
      @order ||= Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :update, @order)

      if @order.update_attributes(checkout_params)
        redirect_to effective_orders.order_path(@order)
      else
        flash.now[:danger] = "Unable to save order: #{@order.errors.full_messages.to_sentence}. Please try again."
        render :edit
      end
    end

    def show
      @order = Effective::Order.find(params[:id])
      set_page_title

      EffectiveOrders.authorized?(self, :show, @order)
    end

    def index
      @orders = Effective::Order.purchased_by(current_user)
      @pending_orders = Effective::Order.pending.where(user: current_user)

      EffectiveOrders.authorized?(self, :index, Effective::Order.new(user: current_user))
    end

    # Basically an index page.
    # Purchases is an Order History page.  List of purchased orders
    def my_purchases
      @orders = Effective::Order.purchased_by(current_user)

      EffectiveOrders.authorized?(self, :index, Effective::Order.new(user: current_user))
    end

    # Sales is a list of what products beign sold by me have been purchased
    def my_sales
      @order_items = Effective::OrderItem.sold_by(current_user)
      EffectiveOrders.authorized?(self, :index, Effective::Order.new(user: current_user))
    end

    # Thank you for Purchasing this Order. This is where a successfully purchased order ends up
    def purchased # Thank You!
      @order = if params[:id].present?
        Effective::Order.find(params[:id])
      elsif current_user.present?
        Effective::Order.purchased_by(current_user).first
      end

      if @order.blank?
        redirect_to(effective_orders.my_purchases_path) and return
      end

      EffectiveOrders.authorized?(self, :show, @order)

      redirect_to(effective_orders.order_path(@order)) unless @order.purchased?
    end

    def declined
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)

      redirect_to(effective_orders.order_path(@order)) unless @order.declined?
    end

    def resend_buyer_receipt
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)

      if @order.send_order_receipt_to_buyer!
        flash[:success] = "Successfully sent receipt to #{@order.user.email}"
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

    protected

    def order_purchased(details: 'none', provider:, card: 'none', purchased_url: nil, declined_url: nil, email: true)
      begin
        @order.purchase!(details: details, provider: provider, card: card, email: email)

        Effective::Cart.where(user_id: @order.user_id).destroy_all

        if EffectiveOrders.mailer[:send_order_receipt_to_buyer] && @order.user == current_user
          flash[:success] = "Payment successful! An email receipt has been sent to #{@order.user.email}"
        else
          flash[:success] = "Payment successful!"
        end

        redirect_to (purchased_url.presence || effective_orders.order_purchased_path(':id')).gsub(':id', @order.to_param.to_s)
      rescue => e
        flash[:danger] = "An error occurred while processing your payment: #{e.message}.  Please try again."
        redirect_to(declined_url.presence || effective_orders.cart_path).gsub(':id', @order.to_param.to_s)
      end
    end

    def order_declined(details: 'none', provider:, card: 'none', declined_url: nil, message: nil)
      @order.decline!(details: details, provider: provider, card: card) rescue nil

      flash[:danger] = message.presence || 'Payment was unsuccessful. Your credit card was declined by the payment processor. Please try again.'

      redirect_to(declined_url.presence || effective_orders.order_declined_path(@order)).gsub(':id', @order.id.to_s)
    end

    private

    # StrongParameters
    def checkout_params
      params.require(:effective_order).permit(EffectiveOrders.permitted_params)
    end

    def set_page_title
      @page_title ||= case params[:action]
        when 'index'        ; 'Orders'
        when 'show'         ; ((@order.user == current_user && !@order.purchased?) ? 'Checkout' : @order.to_s)
        when 'my_purchases' ; 'Order History'
        when 'my_sales'     ; 'Sales History'
        when 'purchased'    ; 'Thank You'
        when 'declined'     ; 'Payment Declined'
        else 'Checkout'
      end
    end

  end
end
