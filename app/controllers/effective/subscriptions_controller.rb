module Effective
  class SubscriptionsController < ApplicationController
    before_filter :authenticate_user!
    before_filter :assign_customer

    def new
      @subscription = StripeSubscription.new()
      @page_title ||= 'New Subscription'

      EffectiveOrders.authorized?(self, :new, @subscription)
    end

    def create
      @subscription = StripeSubscription.new(subscription_params)
      @page_title ||= 'New Subscription'

      if @subscription.valid? && create_stripe_subscription(@customer, @subscription)
        flash[:success] = "Successfully created subscription"
        redirect_to effective_orders.subscriptions_path
      else
        flash[:error] ||= 'Unable to process payment.  Please try again.'
        render :action => :new
      end
    end

    # This is kind of a 'My Subscriptions' page
    def index
      @page_title ||= 'My Subscriptions'

      @plans = @customer.stripe_plans

      EffectiveOrders.authorized?(self, :read, Effective::StripeSubscription.new())
    end

    def destroy
      @plan = @customer.stripe_plans.find { |plan| plan.id == params[:id] }

      EffectiveOrders.authorized?(self, :destroy, Effective::StripeSubscription.new())

      @subscription = @customer.stripe_customer.subscriptions.all
        .find { |subscription| subscription.plan.id == @plan.id } if @plan.present?

      if @plan.present? && @subscription.present?
        begin
          @subscription.delete()
          @customer.plans.delete(@plan.id)
          @customer.save!
          flash[:success] = "Successfully unsubscribed from #{params[:id]}"
        rescue => e
          flash[:error] = "Unable to unsubscribe.  Message: \"#{e.message}\"."
        end
      else
        flash[:error] = "Unable to find plan #{params[:id]}" unless @plan.present?
        flash[:error] = "Unable to find stripe subscription for #{params[:id]}" unless @subscription.present?
      end

      redirect_to effective_orders.subscriptions_path
    end

    private

    def create_stripe_subscription(customer, subscription)
      Effective::Customer.transaction do
        begin
          customer.plans << subscription.plan
          customer.update_card!(subscription.token)
          customer.stripe_customer.subscriptions.create({:plan => subscription.plan})
        rescue => e
          subscription.errors.add(:plan, customer.errors[:plans].first) if customer.errors[:plans].present?
          flash[:error] = "Unable to checkout with Stripe.  Your credit card has not been charged.  Message: \"#{e.message}\"."
          raise ActiveRecord::Rollback
        end
        return true
      end
      false
    end

    def assign_customer
      @customer ||= Customer.for_user(current_user)
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
