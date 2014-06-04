module Effective
  class SubscriptionsController < ApplicationController
    include EffectiveCartsHelper
    include EffectiveStripeHelper

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:subscriptions] : EffectiveOrders.layout)

    before_filter :authenticate_user!
    before_filter :assign_customer

    # This is a 'My Subscriptions' page
    def index
      @page_title ||= 'My Subscriptions'

      @subscriptions = @customer.subscriptions.purchased

      EffectiveOrders.authorized?(self, :index, Effective::Subscription)
    end

    def new
      @page_title ||= 'New Subscription'

      @subscription = @customer.subscriptions.new()

      purchased_plans = @customer.subscriptions.purchased.map(&:stripe_plan_id)
      @plans = Stripe::Plan.all.reject { |stripe_plan| purchased_plans.include?(stripe_plan.id) }

      EffectiveOrders.authorized?(self, :new, @subscription)
    end

    def create
      @page_title ||= 'New Subscription'

      # Don't let the user create another Subscription object if it's already created
      @subscription = @customer.subscriptions.where(:stripe_plan_id => subscription_params[:stripe_plan_id]).first_or_initialize

      EffectiveOrders.authorized?(self, :create, @subscription)

      if @subscription.update_attributes(subscription_params) && (current_cart.find(@subscription).present? || current_cart.add(@subscription))
        flash[:success] = "Successfully added subscription to cart"
        redirect_to effective_orders.new_order_path
      else
        purchased_plans = @customer.subscriptions.purchased.map(&:stripe_plan_id)
        @plans = Stripe::Plan.all.reject { |stripe_plan| purchased_plans.include?(stripe_plan.id) }

        flash[:error] ||= 'Unable to add subscription to cart.  Please try again.'
        render :action => :new
      end
    end

    def show
      @plan = Stripe::Plan.retrieve(params[:id])
      raise ActiveRecord::RecordNotFound unless @plan.present?

      @subscription = @customer.subscriptions.find { |subscription| subscription.stripe_plan_id == params[:id] }
      @stripe_subscription = @subscription.try(:stripe_subscription)
      raise ActiveRecord::RecordNotFound unless @subscription.present? && @stripe_subscription.present?

      EffectiveOrders.authorized?(self, :show, @subscription)

      @invoices = @customer.stripe_customer.invoices.all.select do |invoice| 
        invoice.lines.any? { |line| line.id == @stripe_subscription.id }
      end

      @page_title ||= "#{@plan.name} Subscription Details"
    end

    def destroy
      @plan = Stripe::Plan.retrieve(params[:id])
      raise ActiveRecord::RecordNotFound unless @plan.present?

      @subscription = @customer.subscriptions.find { |subscription| subscription.stripe_plan_id == params[:id] }
      @stripe_subscription = @subscription.try(:stripe_subscription)
      raise ActiveRecord::RecordNotFound unless @subscription.present?

      EffectiveOrders.authorized?(self, :destroy, @subscription)

      if @subscription.present?
        begin
          @stripe_subscription.delete if @stripe_subscription
          @subscription.destroy
          flash[:success] = "Successfully unsubscribed from #{params[:id]}"
        rescue => e
          flash[:error] = "Unable to unsubscribe.  Message: \"#{e.message}\"."
        end
      else
        flash[:error] = "Unable to find stripe subscription for #{params[:id]}" unless @subscription.present?
      end

      redirect_to effective_orders.subscriptions_path
    end

    private

    def assign_customer
      @customer ||= Customer.for_user(current_user)
    end

    # StrongParameters
    def subscription_params
      begin
        params.require(:effective_subscription).permit(:stripe_plan_id, :stripe_coupon_id)
      rescue => e
        params[:effective_subscription]
      end
    end

  end
end
