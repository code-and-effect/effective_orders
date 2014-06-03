module Effective
  class WebhooksController < ApplicationController
    protect_from_forgery :except => [:stripe]

    # Webhook from stripe
    def stripe
      (head(:ok) and return) if (params[:livemode] == false && Rails.env.production?) || params[:object] != 'event' || params[:id].blank?

      # Dont trust the POST, and instead request the actual event from Stripe
      event = Stripe::Event.retrieve(params[:id]) rescue (head(:ok) and return)

      Effective::Customer.transaction do
        begin
          case event.type
          when 'customer.created'   ; stripe_customer_created(event)
          when 'customer.deleted'   ; stripe_customer_deleted(event)
          when 'customer.subscription.created'    ; stripe_subscription_created(event)
          when 'customer.subscription.deleted'    ; stripe_subscription_deleted(event)
          end
        rescue => e
          Rails.logger.info "Stripe Webhook Error: #{e.message}"
          raise ActiveRecord::Rollback
        end
      end

      head :ok  # Always return success
    end

    private

    def stripe_customer_created(event)
      stripe_customer = event.data.object
      user = ::User.where(:email => stripe_customer.email).first

      if user.present?
        customer = Effective::Customer.for_user(user)  # This is a first_or_create
        customer.stripe_customer_id = stripe_customer.id
        customer.save!
      end
    end

    def stripe_customer_deleted(event)
      stripe_customer = event.data.object
      user = ::User.where(:email => stripe_customer.email).first

      if user.present?
        customer = Effective::Customer.where(:user_id => user.id).first
        customer.destroy! if customer
      end
    end

    def stripe_subscription_created(event)
      stripe_subscription = event.data.object
      customer = Effective::Customer.where(:stripe_customer_id => stripe_subscription.customer).first

      if customer.present?
        subscription = customer.subscriptions.where(:stripe_plan_id => stripe_subscription.plan.id).first_or_initialize

        subscription.stripe_subscription_id = stripe_subscription.id
        subscription.stripe_plan_id = stripe_subscription.plan.id
        subscription.stripe_coupon_id = stripe_subscription.discount.coupon.id if stripe_subscription.discount.present?

        subscription.save!

        # Now we have to purchase it
        order = Effective::Order.new(subscription)
        order.user = customer.user
        order.purchase!("via Stripe webhook #{event.id}")
      end
    end

    def stripe_subscription_deleted(event)
      stripe_subscription = event.data.object
      customer = Effective::Customer.where(:stripe_customer_id => stripe_subscription.customer).first

      if customer.present?
        customer.subscriptions.find { |subscription| subscription.stripe_plan_id == stripe_subscription.plan.id }.try(:destroy)
      end
    end

  end
end
