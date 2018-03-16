module Admin
  class OrdersController < ApplicationController
    before_action :authenticate_user!

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_orders] : EffectiveOrders.layout)

    # def effective_resource
    #   @_effective_resource ||= Effective::Resource.new('effective/order', namespace: :admin)
    # end

    def new
      @order = Effective::Order.new

      if params[:user_id]
        @order.user = User.where(id: params[:user_id]).first
      end

      if params[:duplicate_id]
        @duplicate = Effective::Order.deep.find(params[:duplicate_id])
        EffectiveOrders.authorize!(self, :show, @duplicate)

        @order.add(@duplicate)
      end

      @page_title = 'New Order'

      raise 'please install cocoon gem to use this page' unless defined?(Cocoon)

      authorize_effective_order!
    end

    def create
      @user = User.find_by_id(order_params[:user_id])
      @order = Effective::Order.new(user: @user)

      authorize_effective_order!
      error = nil

      Effective::Order.transaction do
        begin
          (order_params[:order_items_attributes] || {}).each do |_, item_attrs|
            purchasable = Effective::Product.new(item_attrs[:purchasable_attributes])
            @order.add(purchasable, quantity: item_attrs[:quantity])
          end

          @order.attributes = order_params.except(:order_items_attributes, :user_id)
          @order.skip_minimum_charge_validation = true

          @order.pending!

          message = 'Successfully created order'
          message << ". A request for payment has been sent to #{@order.user.email}" if @order.send_payment_request_to_buyer?
          flash[:success] = message

          redirect_to(admin_redirect_path) and return
        rescue => e
          error = e.message
          raise ActiveRecord::Rollback
        end
      end

      @page_title = 'New Order'
      flash.now[:danger] = flash_danger(@order)
      render :new
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

      Effective::Order.transaction do
        begin
          @order.assign_attributes(order_params)
          @order.skip_minimum_charge_validation = true

          @order.save!
          redirect_to(admin_redirect_path) and return
        rescue => e
          raise ActiveRecord::Rollback
        end
      end

      flash.now[:danger] = "Unable to update order: #{@order.errors.full_messages.to_sentence}"
      render :edit
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

      authorize_effective_order!

      if request.get?
        @order.assign_confirmed_if_valid!
        render :checkout and return
      end

      Effective::Order.transaction do
        begin
          @order.assign_attributes(checkout_params)
          @order.skip_minimum_charge_validation = true

          @order.confirm!
          redirect_to(effective_orders.checkout_admin_order_path(@order)) and return
        rescue => e
          raise ActiveRecord::Rollback
        end
      end

      flash.now[:danger] = "Unable to proceed: #{flash_errors(@order)}. Please try again."
      render :checkout
    end

    def index
      @datatable = EffectiveOrdersDatatable.new(self)

      @page_title = 'Orders'

      authorize_effective_order!
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
      @order = Effective::Order.pending.find(params[:id])
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

    def bulk_send_payment_request
      @orders = Effective::Order.pending.where(id: params[:ids])

      begin
        authorize_effective_order!

        @orders.each { |order| order.send_payment_request_to_buyer! }
        render json: { status: 200, message: "Successfully sent #{@orders.length} payment request emails"}
      rescue => e
        render json: { status: 500, message: "Bulk send payment request error: #{e.message}" }
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
      EffectiveOrders.authorize!(self, :admin, :effective_orders)
      EffectiveOrders.authorize!(self, action_name.to_sym, @order || Effective::Order)
    end

    def admin_redirect_path
      # Allow an app to define effective_orders_admin_redirect_path in their ApplicationController
      path = if self.respond_to?(:effective_orders_admin_redirect_path)
        effective_orders_admin_redirect_path(params[:commit], @order)
      end

      return path if path.present?

      case params[:commit].to_s
      when 'Save'               ; effective_orders.admin_order_path(@order)

      when 'Continue'           ; effective_orders.admin_orders_path
      when 'Add New'            ; effective_orders.new_admin_order_path(user_id: @order.user.try(:to_param))
      when 'Duplicate'          ; effective_orders.new_admin_order_path(duplicate_id: @order.to_param)
      when 'Checkout'           ; effective_orders.checkout_admin_order_path(@order.to_param)

      else effective_orders.admin_order_path(@order)
      end
    end

  end
end
