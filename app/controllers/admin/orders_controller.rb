module Admin
  class OrdersController < ApplicationController
    before_filter :authenticate_user!   # This is devise, ensure we're logged in.

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_orders] : EffectiveOrders.layout)

    def index
      @datatable = Effective::Datatables::Orders.new() if defined?(EffectiveDatatables)
      @page_title = 'Orders'

      authorize_effective_order!
    end

    # We use the show action as an edit screen too
    def show
      @order = Effective::Order.find(params[:id])
      @page_title = "Order ##{@order.to_param}"

      authorize_effective_order!
    end

    def update
      @order = Effective::Order.find(params[:id])
      @page_title = "Order ##{@order.to_param}"

      authorize_effective_order!

      if @order.update_attributes(order_params)
        if params[:commit].to_s.downcase == 'save internal note'
          flash[:success] = 'Successfully updated internal note'
        else
          flash[:success] = 'Successfully updated order'
        end

        redirect_to effective_orders.admin_order_path(@order)
      else
        flash.now[:danger] = 'Unable to update order'
        render action: :show
      end
    end

    def new
      @order = Effective::Order.new
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

      if @order.create_as_pending
        path_for_redirect = params[:commit] == 'Save and Add New' ? effective_orders.new_admin_order_path : effective_orders.admin_order_path(@order)
        message = 'Successfully created order'
        message << ". #{@order.user.email} has been sent a request for payment." if @order.send_payment_request_to_buyer?
        flash[:success] = message
        redirect_to path_for_redirect
      else
        @page_title = 'New Order'
        flash.now[:danger] = 'Unable to create order'
        render :new
      end
    end

    def mark_as_paid
      @order = Effective::Order.find(params[:id])
      @page_title = 'Mark as Paid'

      authorize_effective_order!

      if request.patch? || request.post?  # They are submitting the form to mark an order as paid
        purchased = false

        @order.attributes = order_params.except(:payment, :payment_provider, :payment_card)

        begin
          purchased = @order.purchase!(
            details: order_params[:payment],
            provider: order_params[:payment_provider],
            card: order_params[:payment_card],
            email: @order.send_mark_as_paid_email_to_buyer?,
          )
        rescue => e
          purchased = false
        end

        if purchased
          flash[:success] = 'Order marked as paid successfully'
          redirect_to effective_orders.admin_order_path(@order)
        else
          flash.now[:danger] = "Unable to mark order as paid: #{@order.errors.full_messages.to_sentence}"
          render action: :mark_as_paid
        end
      end
    end

    def send_payment_request
      @order = Effective::Order.find(params[:id])
      authorize_effective_order!

      if @order.send_payment_request_to_buyer!
        flash[:success] = "Successfully sent payment request to #{@order.user.email}"
      else
        flash[:danger] = 'Unable to send payment request'
      end

      request.referrer ? (redirect_to :back) : (redirect_to effective_orders.admin_order_path(@order))
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

    def authorize_effective_order!
      EffectiveOrders.authorized?(self, :admin, :effective_orders)
      EffectiveOrders.authorized?(self, action_name.to_sym, @order || Effective::Order)
    end

  end
end
