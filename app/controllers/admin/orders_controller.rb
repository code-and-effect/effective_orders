module Admin
  class OrdersController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_orders) }

    include Effective::CrudController

    if (config = EffectiveOrders.layout)
      layout(config.kind_of?(Hash) ? config[:admin] : config)
    end

    submit :save, 'Continue', redirect: :index
    submit :save, 'Add New', redirect: -> { effective_orders.new_admin_order_path(user_id: resource.user&.to_param) }
    submit :save, 'Duplicate', redirect: -> { effective_orders.new_admin_order_path(duplicate_id: resource.to_param) }
    submit :save, 'Checkout', redirect: -> { effective_orders.checkout_admin_order_path(resource) }

    submit :save, 'Save', success: -> {
      message = flash_success(resource, params[:action])
      message << ". A request for payment has been sent to #{resource.emails_send_to}" if resource.send_payment_request_to_buyer?
      message
    }

    def create
      @order = Effective::Order.new
      @order.assign_attributes(permitted_params)

      authorize_effective_order!

      @page_title ||= 'New Order'

      if save_resource(@order, :pending)
        respond_with_success(@order, :save)
      else
        respond_with_error(@order, :save)
      end
    end

    # The show page posts to this action
    # See Effective::OrdersController checkout
    def checkout
      @order = Effective::Order.was_not_purchased.find(params[:id])

      authorize_effective_order!

      @page_title ||= 'Checkout'

      if request.get?
        @order.assign_confirmed_if_valid!
        render(:checkout)
        return
      end

      # Otherwise a post
      @order.assign_attributes(checkout_params)

      if (@order.confirm! rescue false)
        redirect_to(effective_orders.checkout_admin_order_path(@order))
      else
        flash.now[:danger] = "Unable to proceed: #{flash_errors(@order)}. Please try again."
        render :checkout
      end
    end

    def destroy
      @order = Effective::Order.all.was_not_purchased.find(params[:id])

      authorize_effective_order!

      if @order.destroy
        flash[:success] = 'Successfully deleted order'
      else
        flash[:danger] = "Unable to delete order: #{@order.errors.full_messages.to_sentence}"
      end

      redirect_to(effective_orders.admin_orders_path)
    end

    def send_payment_request
      @order = Effective::Order.was_not_purchased.find(params[:id])
      authorize_effective_order!

      if @order.send_payment_request_to_buyer!
        flash[:success] = "A request for payment has been sent to #{@order.emails_send_to}"
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

    def bulk_send_payment_request
      @orders = Effective::Order.was_not_purchased.where(id: params[:ids])

      begin
        authorize_effective_order!

        @orders.each { |order| order.send_payment_request_to_buyer! }
        render json: { status: 200, message: "Successfully sent #{@orders.length} payment request emails"}
      rescue => e
        render json: { status: 500, message: "Bulk send payment request error: #{e.message}" }
      end
    end

    private

    def permitted_params
      params.require(:effective_order).permit!
    end

    def checkout_params
      params.require(:effective_order).permit(EffectiveOrders.permitted_params)
    end

    def authorize_effective_order!
      EffectiveResources.authorize!(self, action_name.to_sym, @order || Effective::Order)
    end

  end
end
