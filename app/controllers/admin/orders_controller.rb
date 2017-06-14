module Admin
  class OrdersController < ApplicationController
    before_action :authenticate_user!

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_orders] : EffectiveOrders.layout)

    def new
      @order = Effective::Order.new
      @order.user = (User.find(params[:user_id]) rescue nil) if params[:user_id]

      @page_title = 'New Order'

      authorize_effective_order!
    end

    def create
      @user = User.find_by_id(order_params[:user_id])
      @order = Effective::Order.new(user: @user)

      authorize_effective_order!

      (order_params[:order_items_attributes] || {}).each do |_, item_attrs|
        purchasable = Effective::Product.new(item_attrs[:purchasable_attributes])
        @order.add(purchasable, quantity: item_attrs[:quantity])
      end

      @order.attributes = order_params.except(:order_items_attributes, :user_id)

      begin

        if @order.refund?
          if @order.create_as_refund
            message = 'Successfully created refund'
            message << ". A receipt has been sent to #{@order.user.email}" if @order.send_payment_request_to_buyer?
            flash[:success] = message
          else
            raise 'unable to save refund'
          end
        else
          if @order.create_as_pending
            message = 'Successfully created order'
            message << ". A request for payment has been sent to #{@order.user.email}" if @order.send_payment_request_to_buyer?
            flash[:success] = message
          else
            raise 'unable to save pending order'
          end
        end

        redirect_to(admin_redirect_path)

      rescue => e
        @page_title = 'New Order'
        flash[:success] = nil
        flash.now[:danger] = "Unable to create order: #{@order.errors.full_messages.to_sentence}"
        render :new
      end
    end

    def edit
      @order = Effective::Order.find(params[:id])
      @page_title ||= @order.to_s

      authorize_effective_order!
    end

    def update
      @order = Effective::Order.find(params[:id])
      @page_title ||= @order.to_s

      authorize_effective_order!

      if @order.update_attributes(order_params)
        flash[:success] = 'Successfully updated order'
        redirect_to(admin_redirect_path)
      else
        flash.now[:danger] = "Unable to update order: #{@order.errors.full_messages.to_sentence}"
        render :edit
      end
    end

    def show
      @order = Effective::Order.find(params[:id])
      @page_title ||= @order.to_s

      authorize_effective_order!
    end

    # The show page posts to this action
    # See Effective::OrdersController checkout
    def checkout
      @order = Effective::Order.find(params[:id])
      @page_title ||= 'Checkout'

      authorize_effective_order!

      if @order.update_attributes(checkout_params)
        redirect_to(effective_orders.admin_order_path(@order))
      else
        flash.now[:danger] = "Unable to save order: #{@order.errors.full_messages.to_sentence}. Please try again."
        render :show
      end
    end

    def index
      @datatable = EffectiveOrdersDatatable.new(self)

      @page_title = 'Orders'

      authorize_effective_order!
    end

    def destroy
      @order = Effective::Order.find(params[:id])

      authorize_effective_order!

      if @order.destroy
        flash[:success] = 'Successfully deleted order'
      else
        flash[:danger] = "Unable to delete order: #{@order.errors.full_messages.to_sentence}"
      end

      redirect_to(effective_orders.admin_orders_path)
    end

    def send_payment_request
      @order = Effective::Order.find(params[:id])
      authorize_effective_order!

      if @order.send_payment_request_to_buyer!
        flash[:success] = "A request for payment has been sent to #{@order.user.email}"
      else
        flash[:danger] = 'Unable to send payment request'
      end

      if respond_to?(:redirect_back)
        redirect_back(fallback_location: effective_orders.admin_order_path(@order))
      elsif request.referrer.present?
        redirect_to :back
      else
        redirect_to effective_orders.admin_order_path(@order)
      end
    end

    private

    def order_params
      params.require(:effective_order).permit(:user_id, :send_payment_request_to_buyer,
        :note_internal, :note_to_buyer,
        :payment_provider, :payment_card, :payment, :send_mark_as_paid_email_to_buyer,
        order_items_attributes: [
          :quantity, :_destroy, purchasable_attributes: [
            :title, :price, :tax_exempt
          ]
        ]
      )
    end

    def checkout_params
      params.require(:effective_order).permit(EffectiveOrders.permitted_params)
    end

    def authorize_effective_order!
      EffectiveOrders.authorized?(self, :admin, :effective_orders)
      EffectiveOrders.authorized?(self, action_name.to_sym, @order || Effective::Order)
    end

    def admin_redirect_path
      # Allow an app to define effective_orders_admin_redirect_path in their ApplicationController
      path = if self.respond_to?(:effective_orders_admin_redirect_path)
        effective_orders_admin_redirect_path(params[:commit], @order)
      end

      return path if path.present?

      case params[:commit].to_s
      when 'Save'               ; effective_orders.admin_order_path(@order)
      when 'Save and Continue'  ; effective_orders.admin_orders_path
      when 'Save and Add New'   ; effective_orders.new_admin_order_path(user_id: @order.user.try(:to_param))
      else effective_orders.admin_order_path(@order)
      end
    end

  end
end
