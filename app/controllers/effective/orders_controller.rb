module Effective
  class OrdersController < ApplicationController
    include EffectiveCartsHelper

    include Providers::Cheque if EffectiveOrders.cheque_enabled
    include Providers::Moneris if EffectiveOrders.moneris_enabled
    include Providers::Paypal if EffectiveOrders.paypal_enabled
    include Providers::Stripe if EffectiveOrders.stripe_enabled
    include Providers::StripeConnect if EffectiveOrders.stripe_connect_enabled
    include Providers::Ccbill if EffectiveOrders.ccbill_enabled
    include Providers::AppCheckout if EffectiveOrders.app_checkout_enabled

    include Providers::Pretend if EffectiveOrders.allow_pretend_purchase_in_development && !Rails.env.production?
    include Providers::Pretend if EffectiveOrders.allow_pretend_purchase_in_production && Rails.env.production?

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:orders] : EffectiveOrders.layout)

    if defined?(Devise)
      before_filter :authenticate_user!, except: [:paypal_postback, :ccbill_postback]
    end

    before_filter :set_page_title, except: [:show]

    # This is the entry point for the "Checkout" buttons
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
        flash[:danger] = @order.errors[:total].first.gsub(EffectiveOrders.minimum_charge.to_i.to_s, view_context.price_to_currency(EffectiveOrders.minimum_charge.to_i))
        redirect_to(effective_orders.cart_path)
        return
      end

      @order.errors.clear
      @order.billing_address.try(:errors).try(:clear)
      @order.shipping_address.try(:errors).try(:clear)

      render :checkout_step1
    end

    def edit
      @order ||= Effective::Order.find(params[:id])

      EffectiveOrders.authorized?(self, :edit, @order)

      render :checkout_step1
    end

    def create
      @order ||= Effective::Order.new(current_cart, user: current_user)
      save_order_and_redirect_to_step2
    end

    # If there is an existing order, it will be posted to the /update action, instead of /create
    def update
      @order ||= Effective::Order.find(params[:id])
      save_order_and_redirect_to_step2
    end

    def save_order_and_redirect_to_step2
      (redirect_to effective_orders.cart_path and return) if (@order.blank? || current_user.blank?)

      @order.attributes = order_params
      @order.user_id = current_user.id

      EffectiveOrders.authorized?(self, (@order.persisted? ? :update : :create), @order)

      @order.valid?  # This makes sure the correct shipping_address is copied from billing_address if shipping_address_same_as_billing

      Effective::Order.transaction do
        begin
          if @order.save_billing_address? && @order.user.respond_to?(:billing_address=) && @order.billing_address.present?
            @order.user.billing_address = @order.billing_address
          end

          if @order.save_shipping_address? && @order.user.respond_to?(:shipping_address=) && @order.shipping_address.present?
            @order.user.shipping_address = @order.shipping_address
          end

          @order.save!

          if @order.total == 0 && EffectiveOrders.allow_free_orders
            order_purchased(details: 'automatic purchase of free order', provider: 'free', card: 'none')
          else
            redirect_to(effective_orders.order_path(@order))  # This goes to checkout_step2
          end

          return true
        rescue => e
          Rails.logger.info e.message
          flash.now[:danger] = "Unable to save order: #{@order.errors.full_messages.to_sentence}.  Please try again."
          raise ActiveRecord::Rollback
        end
      end

      # Fall back to checkout step 1
      render :checkout_step1
    end

    def show
      @order = Effective::Order.find(params[:id])
      EffectiveOrders.authorized?(self, :show, @order)

      @page_title ||= (
        if @order.purchased?
          'Receipt'
        elsif @order.user != current_user
          @order.pending? ? "Pending Order ##{@order.to_param}" : "Order ##{@order.to_param}"
        else
          'Checkout'
        end
      )

      render(:checkout_step2) if @order.purchased? == false && @order.user == current_user
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

    # Thank you for Purchasing this Order.  This is where a successfully purchased order ends up
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

    # An error has occurred, please try again
    def declined # An error occurred!
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

      redirect_to(request.referer.present? ? :back : effective_orders.order_path(@order))
    end

    protected

    def order_purchased(details: 'none', provider:, card: 'none', redirect_url: nil, declined_redirect_url: nil)
      begin
        @order.purchase!(details: details, provider: provider, card: card)

        Effective::Cart.where(user_id: @order.user_id).try(:destroy_all) # current_cart won't work for provider post backs here

        if EffectiveOrders.mailer[:send_order_receipt_to_buyer]
          flash[:success] = "Payment successful! Please check your email for a receipt."
        else
          flash[:success] = "Payment successful!"
        end

        redirect_to (redirect_url.presence || effective_orders.order_purchased_path(':id')).gsub(':id', @order.to_param.to_s)
      rescue => e
        flash[:danger] = "An error occurred while processing your payment: #{e.message}.  Please try again."
        redirect_to(declined_redirect_url.presence || effective_orders.cart_path).gsub(':id', @order.to_param.to_s)
      end
    end

    def order_declined(details: 'none', provider:, card: 'none', redirect_url: nil, message: nil)
      @order.decline!(details: details, provider: provider, card: card) rescue nil

      flash[:danger] = message.presence || 'Payment was unsuccessful. Your credit card was declined by the payment processor. Please try again.'

      redirect_to(redirect_url.presence || effective_orders.order_declined_path(@order)).gsub(':id', @order.id.to_s)
    end

    private

    # StrongParameters
    def order_params
      begin
        params.require(:effective_order).permit(EffectiveOrders.permitted_params)
      rescue => e
        params[:effective_order] || {}
      end
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
