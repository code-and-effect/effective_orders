module Effective
  class SubscriptionsController < ApplicationController
    before_filter :authenticate_user!

    def new
      @subscription = StripeSubscription.new()
      @page_title ||= 'New Subscription'

      @customer = Customer.for_user(current_user)
      @plans = available_stripe_plans_for(@customer)

      EffectiveOrders.authorized?(self, :new, @subscription)
    end

    def create
      @subscription = StripeSubscription.new(subscription_params)
      @page_title ||= 'New Subscription'

      @customer = Customer.for_user(current_user)

      if @subscription.valid? && create_stripe_subscription(@customer, @subscription)
        flash[:success] = "Successfully created subscription"
        redirect_to effective_orders.subscriptions_path
      else
        @plans = available_stripe_plans_for(@customer)
        flash[:error] ||= 'Unable to process payment.  Please try again.'
        render :action => :new
      end
    end

    # This is kind of a 'My Subscriptions' page
    def index
      @page_title ||= 'My Subscriptions'

      EffectiveOrders.authorized?(self, :read, Effective::StripeSubscription.new())
    end

    private

    def create_stripe_subscription(customer, subscription)
      Effective::Customer.transaction do
        begin
          customer.stripe_plans << subscription.plan
          customer.update_card!(subscription.token)
          customer.stripe_customer.subscriptions.create({:plan => @subscription.plan})
        rescue => e
          subscription.errors.add(:plan, customer.errors[:stripe_plans].first) if customer.errors[:stripe_plans].present?
          flash[:error] = "Unable to checkout with Stripe.  Your credit card has not been charged.  Message: \"#{e.message}\"."
          raise ActiveRecord::Rollback
        end
        return true
      end
      false
    end

    def available_stripe_plans_for(customer)
      Stripe::Plan.all.reject { |plan| customer.stripe_plans.include?(plan.id) }
    end

    # StrongParameters
    def subscription_params
      begin
        params.require(:effective_stripe_subscription).permit(:plan, :token)
      rescue => e
        params[:effective_stripe_subscription]
      end
    end

  end
end
