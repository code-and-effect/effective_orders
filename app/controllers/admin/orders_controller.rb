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

    # def create
    #   @user = current_user.class.find_by_id(permitted_params[:user_id])
    #   @order = Effective::Order.new(user: @user)

    #   authorize_effective_order!
    #   error = nil

    #   Effective::Order.transaction do
    #     begin
    #       (permitted_params[:order_items_attributes] || {}).each do |_, item_attrs|
    #         purchasable = Effective::Product.new(item_attrs[:purchasable_attributes])
    #         @order.add(purchasable, quantity: item_attrs[:quantity])
    #       end

    #       @order.attributes = permitted_params.except(:order_items_attributes, :user_id)
    #       @order.pending!

    #       message = 'Successfully created order'
    #       message << ". A request for payment has been sent to #{@order.emails_send_to}" if @order.send_payment_request_to_buyer?
    #       flash[:success] = message

    #       redirect_to(admin_redirect_path) and return
    #     rescue => e
    #       error = e.message
    #       raise ActiveRecord::Rollback
    #     end
    #   end

    #   @page_title = 'New Order'
    #   flash.now[:danger] = flash_danger(@order) + error.to_s
    #   render :new
    # end

    # The show page posts to this action
    # See Effective::OrdersController checkout
    def checkout
      @order = Effective::Order.not_purchased.find(params[:id])

      authorize_effective_order!

      @page_title ||= 'Checkout'

      if request.get?
        @order.assign_confirmed_if_valid!
        render :checkout and return
      end

      Effective::Order.transaction do
        begin
          @order.assign_attributes(checkout_params)
          @order.confirm!
          redirect_to(effective_orders.checkout_admin_order_path(@order)) and return
        rescue => e
          raise ActiveRecord::Rollback
        end
      end

      flash.now[:danger] = "Unable to proceed: #{flash_errors(@order)}. Please try again."
      render :checkout
    end

    def destroy
      @order = Effective::Order.all.not_purchased.find(params[:id])

      authorize_effective_order!

      if @order.destroy
        flash[:success] = 'Successfully deleted order'
      else
        flash[:danger] = "Unable to delete order: #{@order.errors.full_messages.to_sentence}"
      end

      redirect_to(effective_orders.admin_orders_path)
    end

    def send_payment_request
      @order = Effective::Order.not_purchased.find(params[:id])
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
      @orders = Effective::Order.not_purchased.where(id: params[:ids])

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

    def admin_redirect_path
      case params[:commit].to_s
      when 'Save'               ; effective_orders.admin_order_path(@order)
      when 'Continue'           ; effective_orders.admin_orders_path
      when 'Add New'            ; effective_orders.new_admin_order_path(user_id: @order.user.try(:to_param))
      when 'Duplicate'          ; effective_orders.new_admin_order_path(duplicate_id: @order.to_param)
      when 'Checkout'           ; effective_orders.checkout_admin_order_path(@order.to_param)
      else
        effective_orders.admin_order_path(@order)
      end
    end

  end
end
