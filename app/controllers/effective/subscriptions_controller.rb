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

      EffectiveOrders.authorized?(self, :read, Effective::Subscription.new())
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

    # def show
    #   @plan = @customer.stripe_plans.find { |plan| plan.id == params[:id] }
    #   raise ActiveRecord::RecordNotFound unless @plan.present?

    #   @subscription = @customer.stripe_customer.subscriptions.all.find { |subscription| subscription.plan.id == @plan.id }
    #   raise ActiveRecord::RecordNotFound unless @subscription.present?

    #   EffectiveOrders.authorized?(self, :read, Effective::StripeSubscription.new())

    #   @invoices = @customer.stripe_customer.invoices.all.select do |invoice| 
    #     invoice.lines.any? { |line| line.id == @subscription.id }
    #   end

    #   @page_title ||= "#{@plan.name} Subscription Details"
    # end

    # def destroy
    #   @plan = @customer.stripe_plans.find { |plan| plan.id == params[:id] }

    #   raise ActiveRecord::RecordNotFound unless @plan.present?
    #   EffectiveOrders.authorized?(self, :destroy, Effective::StripeSubscription.new())

    #   @subscription = @customer.stripe_customer.subscriptions.all.find { |subscription| subscription.plan.id == @plan.id }

    #   if @subscription.present?
    #     begin
    #       @subscription.delete()
    #       @customer.plans.delete(@plan.id)
    #       @customer.save!
    #       flash[:success] = "Successfully unsubscribed from #{params[:id]}"
    #     rescue => e
    #       flash[:error] = "Unable to unsubscribe.  Message: \"#{e.message}\"."
    #     end
    #   else
    #     flash[:error] = "Unable to find stripe subscription for #{params[:id]}" unless @subscription.present?
    #   end

    #   redirect_to effective_orders.subscriptions_path
    # end

    private

    # def create_stripe_subscription(customer, subscription)
    #   Effective::Customer.transaction do
    #     begin
    #       customer.plans << subscription.plan
    #       customer.update_card!(subscription.token)
    #       if subscription.coupon.present?
    #         customer.stripe_customer.subscriptions.create({:plan => subscription.plan, :coupon => subscription.coupon})
    #       else
    #         customer.stripe_customer.subscriptions.create({:plan => subscription.plan})
    #       end
    #     rescue => e
    #       subscription.errors.add(:plan, customer.errors[:plans].first) if customer.errors[:plans].present?
    #       subscription.errors.add(:coupon, e.message) if e.message.downcase.include?('coupon')
    #       flash[:error] = "Unable to checkout with Stripe.  Your credit card has not been charged.  Message: \"#{e.message}\"."
    #       raise ActiveRecord::Rollback
    #     end
    #     return true
    #   end
    #   false
    # end

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
