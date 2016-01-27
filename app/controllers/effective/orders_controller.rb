module Effective
  class OrdersController < ApplicationController
    include EffectiveCartsHelper

    include Providers::Moneris if EffectiveOrders.moneris_enabled
    include Providers::Paypal if EffectiveOrders.paypal_enabled
    include Providers::Stripe if EffectiveOrders.stripe_enabled
    include Providers::StripeConnect if EffectiveOrders.stripe_connect_enabled
    include Providers::Ccbill if EffectiveOrders.ccbill_enabled
    include Providers::AppCheckout if EffectiveOrders.app_checkout_enabled

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:orders] : EffectiveOrders.layout)

    before_filter :authenticate_user!, :except => [:paypal_postback, :ccbill_postback]
    before_filter :set_page_title

    # This is the entry point for the "Checkout" buttons
    def new
      @order ||= Order.new(current_cart, current_user)

      EffectiveOrders.authorized?(self, :new, @order)

      # We're only going to check for a subset of errors on this step,
      # with the idea that we don't want to create an Order object if the Order is totally invalid
      @order.valid?

      if @order.errors[:order_items].present?
        flash[:danger] = @order.errors[:order_items].first
        redirect_to effective_orders.cart_path
      elsif @order.errors[:total].present?
        flash[:danger] = @order.errors[:total].first.gsub(EffectiveOrders.minimum_charge.to_i.to_s, view_context.price_to_currency(EffectiveOrders.minimum_charge.to_i))
        redirect_to effective_orders.cart_path
      end
    end

    def create
      @order ||= Order.new(current_cart, current_user)
      @order.attributes = order_params

      if EffectiveOrders.require_shipping_address
        if @order.shipping_address_same_as_billing? && @order.billing_address.present?
          @order.shipping_address = @order.billing_address
        end
      end

      EffectiveOrders.authorized?(self, :create, @order)

      Effective::Order.transaction do
        begin
          if @order.save_billing_address? && @order.user.respond_to?(:billing_address) && @order.billing_address.try(:empty?) == false
            @order.user.billing_address = @order.billing_address
          end

          if @order.save_shipping_address? && @order.user.respond_to?(:shipping_address) && @order.shipping_address.try(:empty?) == false
            @order.user.shipping_address = @order.shipping_address
          end

          @order.save!

          if @order.total == 0 && EffectiveOrders.allow_free_orders
            order_purchased('automatic purchase of free order.')
          else
            redirect_to(effective_orders.order_path(@order))
          end

          return
        rescue => e
          Rails.logger.info e.message
          flash.now[:danger] = "An error has occurred: #{e.message}. Please try again."
          raise ActiveRecord::Rollback
        end
      end

      render :action => :new
    end

    def show
      @order = Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)

      if @order.purchased? == false
        @page_title = 'Checkout'
        render(:checkout) and return
      end
    end

    def index
      redirect_to effective_orders.my_purchases_path
    end

    # Basically an index page.
    # Purchases is an Order History page.  List of purchased orders
    def my_purchases
      @orders = Order.purchased_by(current_user)
      EffectiveOrders.authorized?(self, :index, Effective::Order.new(user: current_user))
    end

    # Sales is a list of what products beign sold by me have been purchased
    def my_sales
      @order_items = OrderItem.sold_by(current_user)
      EffectiveOrders.authorized?(self, :index, Effective::Order.new(user: current_user))
    end

    # Thank you for Purchasing this Order.  This is where a successfully purchased order ends up
    def purchased # Thank You!
      @order = Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)
    end

    # An error has occurred, please try again
    def declined # An error occurred!
      @order = Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)
    end

    def resend_buyer_receipt
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)

      if @order.send_order_receipt_to_buyer!
        flash[:success] = "Successfully resent order receipt to #{@order.user.email}"
      else
        flash[:danger] = "Unable to send order receipt."
      end

      redirect_to(:back) rescue effective_orders.order_path(@order)
    end

    def pretend_purchase
      @order = Order.find(params[:id])
      EffectiveOrders.authorized?(self, :update, @order)

      if (Rails.env.production? == false && EffectiveOrders.allow_pretend_purchase_in_development)
        order_purchased('for pretend', params[:purchased_redirect_url], params[:declined_redirect_url])
      end

      if (Rails.env.production? == true && EffectiveOrders.allow_pretend_purchase_in_production)
        order_purchased('for pretend', params[:purchased_redirect_url], params[:declined_redirect_url])
      end

    end

    protected

    def order_purchased(details = nil, redirect_url = nil, declined_redirect_url = nil)
      begin
        @order.purchase!(details)
        Cart.where(user_id: @order.user_id).try(:destroy_all) # current_cart won't work for provider post backs here

        if EffectiveOrders.mailer[:send_order_receipt_to_buyer]
          flash[:success] = "Payment successful! Please check your email for a receipt."
        else
          flash[:success] = "Payment successful!"
        end

        redirect_to (redirect_url.presence || effective_orders.order_purchased_path(':id')).gsub(':id', @order.to_param.to_s)
      rescue => e
        flash[:danger] = "An error occurred while processing your payment: #{e.message}.  Please try again."
        redirect_to (declined_redirect_url.presence || effective_orders.cart_path).gsub(':id', @order.to_param.to_s)
      end
    end

    # options:
    # flash: What flash message should be displayed
    def order_declined(details = nil, redirect_url = nil, options = {})
      flash_msg = options.fetch(:flash, "Payment was unsuccessful. Your credit card was declined by the payment processor. Please try again.")

      @order.decline!(details) rescue nil
      flash[:danger] = flash_msg

      redirect_to (redirect_url.presence || effective_orders.order_declined_path(@order)).gsub(':id', @order.id.to_s)
    end

    private

    # StrongParameters
    def order_params
      begin
        params.require(:effective_order).permit(
          :save_billing_address, :save_shipping_address, :shipping_address_same_as_billing,
          :billing_address => [:full_name, :address1, :address2, :city, :country_code, :state_code, :postal_code],
          :shipping_address => [:full_name, :address1, :address2, :city, :country_code, :state_code, :postal_code],
          :user_attributes => (EffectiveOrders.collect_user_fields || []),
          :order_items_attributes => [:stripe_coupon_id, :class, :id]
        )
      rescue => e
        params[:effective_order] || {}
      end
    end

    def set_page_title
      @page_title ||= case params[:action]
        when 'my_purchases' ; 'Order History'
        when 'my_sales'     ; 'Sales History'
        when 'purchased'    ; 'Thank You'
        when 'declined'     ; 'Payment Declined'
        when 'show'         ; 'Order Receipt'
        else 'Checkout'
      end
    end

  end
end
