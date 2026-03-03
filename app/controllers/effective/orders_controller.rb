module Effective
  class OrdersController < ApplicationController
    include Effective::CrudController
    include Concerns::Purchase

    # Update the verify_recaptcha_checkout! method if we add another payment provider here
    include Providers::Cheque
    include Providers::Deluxe
    include Providers::DeluxeDelayed
    include Providers::DeluxeDelayedPurchase
    include Providers::Etransfer
    include Providers::Free
    include Providers::Helcim
    include Providers::MarkAsPaid
    include Providers::Moneris
    include Providers::MonerisCheckout
    include Providers::Paypal
    include Providers::Phone
    include Providers::Pretend
    include Providers::Refund
    include Providers::Stripe

    if (config = EffectiveOrders.layout)
      layout(config.kind_of?(Hash) ? (config[:orders] || config[:application]) : config)
    end

    rate_limit to: 10, within: 1.hour, by: -> { current_user&.id }, only: :checkout

    before_action :authenticate_user!, except: [:free, :paypal_postback, :moneris_postback, :pretend]
    before_action :set_page_title, except: [:show, :edit, :checkout]

    before_action :verify_recaptcha_checkout!, only: [
      :cheque, :deluxe, :deluxe_delayed, :etransfer, :free, :helcim, :mark_as_paid, :moneris_checkout, :phone, :pretend, :refund, :stripe
    ]

    # If you want to use the Add to Cart -> Checkout flow
    # Add one or more items however you do.
    # redirect_to effective_orders.new_order_path, which is here.
    # This is the entry point for any Checkout button.
    # It displayes an order based on the cart
    # Always step1
    def new
      @order ||= Effective::Order.deep.new(view_context.current_cart)

      EffectiveResources.authorize!(self, :new, @order)

      unless @order.valid?
        flash[:danger] = "Unable to proceed: #{flash_errors(@order)}. Please try again."
        redirect_to(effective_orders.cart_path)
        return
      end
    end

    # Confirms an order from the cart.
    def create
      @order ||= Effective::Order.deep.new(view_context.current_cart)
      EffectiveResources.authorize!(self, :create, @order)

      @order.assign_attributes(checkout_params)

      if (@order.confirm! rescue false)
        redirect_to(effective_orders.checkout_order_path(@order))
      else
        flash.now[:danger] = "Unable to proceed: #{flash_errors(@order)}. Please try again."
        render :new
      end
    end

    # Displays the order summary.
    # For unpurchased orders, shows a Checkout button.
    # For purchased orders, shows a Continue button.
    def show
      @order ||= Effective::Order.deep.find(params[:id])
      @page_title ||= @order.to_s

      EffectiveResources.authorize!(self, :show, @order)
    end

    def checkout
      @order ||= Effective::Order.deep.was_not_purchased.find(params[:id])
      @page_title ||= 'Checkout'

      EffectiveResources.authorize!(self, :checkout, @order)
    end

    # Always step1
    def edit
      @order ||= Effective::Order.deep.was_not_purchased.find(params[:id])
      @page_title ||= 'Order Review'

      EffectiveResources.authorize!(self, :edit, @order)
    end

    # Confirms the order from existing order
    def update
      @order ||= Effective::Order.deep.was_not_purchased.find(params[:id])
      EffectiveResources.authorize!(self, :update, @order)

      @order.assign_attributes(checkout_params)

      if (@order.confirm! rescue false)
        redirect_to(effective_orders.checkout_order_path(@order))
      else
        flash.now[:danger] = "Unable to proceed: #{flash_errors(@order)}. Please try again."
        render :edit
      end
    end

    # Thank you for Purchasing this Order. This is where a successfully purchased order ends up
    def purchased # Thank You!
      @order = Effective::Order.deep.purchased.find(params[:id])
      EffectiveResources.authorize!(self, :show, @order)
    end

    def deferred
      @order = Effective::Order.deep.deferred.find(params[:id])
      EffectiveResources.authorize!(self, :show, @order)
    end

    def declined
      @order = Effective::Order.deep.declined.find(params[:id])
      EffectiveResources.authorize!(self, :show, @order)
    end

    # This is used by both the Admin and User
    def send_buyer_receipt
      @order = Effective::Order.deep.purchased.find(params[:id])

      EffectiveResources.authorize!(self, :show, @order)

      if @order.send_order_receipt_to_buyer!
        flash[:success] = "A receipt has been sent to #{@order.emails_send_to}"
      else
        flash[:danger] = "Unable to send receipt."
      end

      redirect_back(fallback_location: effective_orders.order_path(@order))
    end

    def bulk_send_buyer_receipt
      @orders = Effective::Order.deep.purchased.where(id: params[:ids])

      begin
        EffectiveResources.authorize!(self, :index, Effective::Order.new(user: current_user))

        @orders.each do |order|
          next unless EffectiveResources.authorized?(self, :show, order)
          order.send_order_receipt_to_buyer!
        end

        render json: { status: 200, message: "Successfully sent #{@orders.length} receipt emails"}
      rescue Exception => e
        render json: { status: 500, message: "Bulk send buyer receipt error: #{e.message}" }
      end
    end

    def recaptcha
      raise('recaptcha is not enabled') unless EffectiveOrders.recaptcha?
      raise('recaptcha secret key is not set') unless EffectiveOrders.recaptcha_secret_key.present?

      @order = Effective::Order.not_purchased.find(params[:id])
      EffectiveResources.authorize!(self, :update, @order)

      redirect_url = params[:redirect_url].presence || effective_orders.checkout_order_path(@order)

      if verify_recaptcha(secret_key: EffectiveOrders.recaptcha_secret_key)
        session[:recaptcha_verified_order_id] = @order.id
        redirect_to redirect_url
      else
        flash[:danger] = 'Verification failed. Please try again.'
        redirect_to redirect_url
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
        when 'deferred'     ; 'Thank You'
        else 'Checkout'
      end
    end

    def verify_recaptcha_checkout!
      return unless EffectiveOrders.recaptcha?

      unless session[:recaptcha_verified_order_id].to_s == params[:id].to_s
        flash[:danger] = 'Please complete the verification to proceed with payment.'
        redirect_back(fallback_location: effective_orders.checkout_order_path(params[:id]))
      end
    end

  end
end
