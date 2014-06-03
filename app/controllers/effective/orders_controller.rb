module Effective
  class OrdersController < ApplicationController
    include EffectiveCartsHelper

    include Providers::Moneris if EffectiveOrders.moneris_enabled
    include Providers::Paypal if EffectiveOrders.paypal_enabled
    include Providers::Stripe if EffectiveOrders.stripe_enabled
    include Providers::StripeConnect if EffectiveOrders.stripe_connect_enabled

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:orders] : EffectiveOrders.layout)

    before_filter :authenticate_user!, :except => [:paypal_postback]
    before_filter :set_page_title

    # This is the entry point for the "Checkout" buttons
    def new
      @order ||= Order.new(current_cart)
      @order.user = current_user

      EffectiveOrders.authorized?(self, :create, @order)

      unless @order.order_items.present?
        flash[:alert] = 'An order must contain order items.  Please add one or more items to your Cart before proceeding to checkout.'
        redirect_to effective_orders.cart_path
      end
    end

    def create
      @order = Order.new(current_cart)
      @order.user = current_user

      # Passing the order_item_attributes as acts_as_nested creates a new object instead of updating the temporary one.
      # So we have to manually assign some atts
      # Expecting something like "effective_order"=>{"order_items_attributes"=>{"0"=>{"class"=>"Effective::Subscription", "stripe_coupon_id"=>"50OFF", "id"=>"2"}}}
      @order.attributes = order_params.except(:order_items_attributes)

      (order_params[:order_items_attributes] || {}).each do |_, atts|
        order_item = @order.order_items.find { |oi| oi.purchasable.class.name == atts[:class] && oi.purchasable.id == atts[:id].to_i }

        if order_item
          order_item.purchasable.attributes = atts.except(:id, :class)
          order_item.title = order_item.purchasable.title  # Recalculate the Title and Price, as we may have just added a coupon code
          order_item.price = order_item.purchasable.price
        end
      end

      EffectiveOrders.authorized?(self, :create, @order)

      if @order.save
        if @order.save_billing_address || @order.save_shipping_address
          begin
            @order.user.billing_address = @order.billing_address if @order.save_billing_address
            @order.user.shipping_address = @order.shipping_address if @order.save_shipping_address
          rescue => e ; end
          @order.user.save
        end

        order_purchased('zero-dollar order') if @order.total == 0.00
      else
        render :action => :new
      end
    end

    def show
      @order = Order.find(params[:id])
      EffectiveOrders.authorized?(self, :read, @order)
    end

    # Basically an index page.
    # Purchases is an Order History page.  List of purchased orders
    def my_purchases
      @orders = Order.purchased_by(current_user)

      EffectiveOrders.authorized?(self, :index, Effective::Order)
    end

    # Sales is a list of what products beign sold by me have been purchased
    def my_sales
      @order_items = OrderItem.sold_by(current_user)

      EffectiveOrders.authorized?(self, :index, Effective::OrderItem)
    end

    # Thank you for Purchasing this Order.  This is where a successfully purchased order ends up
    def purchased # Thank You!
      @order = Order.find(params[:id])
      EffectiveOrders.authorized?(self, :read, @order)
    end

    # An error has occurred, please try again
    def declined # An error occurred!
      @order = Order.find(params[:id])
      EffectiveOrders.authorized?(self, :read, @order)
    end

    def pretend_purchase
      unless Rails.env.production?
        @order = Order.find(params[:id])
        EffectiveOrders.authorized?(self, :read, @order)
        order_purchased('for pretend')
      end
    end

    protected

    def order_purchased(details = nil)
      @order.purchase!(details)
      current_cart.try(:destroy)

      flash[:notice] = "Successfully purchased order"
      redirect_to effective_orders.order_purchased_path(@order)
    end

    def order_declined(details = nil)
      @order.decline!(details)

      flash[:error] = "Unable to process your order.  Your Cart items have been restored"
      redirect_to effective_orders.order_declined_path(@order)
    end

    private

    # StrongParameters
    def order_params
      begin
        params.require(:effective_order).permit(
          :save_billing_address, :save_shipping_address, :stripe_token,
          :billing_address => [:full_name, :address1, :address2, :city, :country_code, :state_code, :postal_code],
          :shipping_address => [:full_name, :address1, :address2, :city, :country_code, :state_code, :postal_code],
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
        when 'declined'     ; 'Unable to process payment'
        when 'show'         ; 'Order Receipt'
        else 'Checkout' 
      end
    end

  end
end
