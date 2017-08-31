module Effective
  class WebhooksController < ApplicationController
    protect_from_forgery except: [:stripe]
    skip_authorization_check if defined?(CanCan)
    log_page_views if defined?(EffectiveLogging)

    def stripe
      @event = (Stripe::Webhook.construct_event(request.body.read, request.env['HTTP_STRIPE_SIGNATURE'], EffectiveOrders.subscription[:webhook_secret]) rescue nil)
      (head(:bad_request) and return) if !@event || (params[:livemode] == false && Rails.env.production?)

      Rails.logger.info "STRIPE WEBHOOK: #{@event.type}"

      Effective::Customer.transaction do
        case @event.type
        when 'customer.created'
        when 'customer.updated'
        when 'customer.source.created'   # When we update card info
        when 'customer.subscription.created'
        when 'customer.subscription.updated'
        when 'invoice.created'
        when 'invoice.payment_succeeded'
        when 'invoiceitem.created'
        when 'invoiceitem.updated'
        when 'charge.succeeded'
        when 'charge.failed' # Card declined. 4000 0000 0000 0341
        else
          Rails.logger.info "[STRIPE WEBHOOK] Unhandled event type #{@event.type}"
        end
      end

      head(:ok)
    end

    # def rollback_and_raise(&block)
    #   exception = nil

    #   Something.transaction do
    #     begin
    #       yield
    #     rescue => e
    #       exception = e
    #       raise ActiveRecord::Rollback
    #     end
    #   end

    #   raise exception if exception
    #   true
    # end

    # # Webhook from stripe
    # def stripe
    #   (head(:ok) && return) if (params[:livemode] == false && Rails.env.production?) || params[:object] != 'event' || params[:id].blank?

    #   # Dont trust the POST, and instead request the actual event from Stripe
    #   @event = Stripe::Event.retrieve(params[:id]) rescue (head(:ok) && return)

    #   Effective::Customer.transaction do
    #     begin
    #       case @event.type
    #       # customer.source.updated
    #       when 'customer.created' then stripe_customer_created(@event)
    #       when 'customer.deleted' then stripe_customer_deleted(@event)
    #       when 'customer.subscription.created' then stripe_subscription_created(@event)
    #       when 'customer.subscription.deleted' then stripe_subscription_deleted(@event)
    #       when 'invoice.payment_succeeded' then invoice_payment_succeeded(@event)
    #       end
    #     rescue => e
    #       Rails.logger.info "Stripe Webhook Error: #{e.message}"
    #       raise ActiveRecord::Rollback
    #     end
    #   end

    #   head :ok  # Always return success
    # end

    # private

    # def stripe_customer_created(event)
    #   stripe_customer = event.data.object
    #   user = ::User.where(email: stripe_customer.email).first

    #   if user.present?
    #     customer = Effective::Customer.for_user(user)  # This is a first_or_create
    #     customer.stripe_customer_id = stripe_customer.id
    #     customer.save!
    #   end
    # end

    # def stripe_customer_deleted(event)
    #   stripe_customer = event.data.object
    #   user = ::User.where(email: stripe_customer.email).first

    #   if user.present?
    #     customer = Effective::Customer.where(user_id: user.id).first
    #     customer.destroy! if customer
    #   end
    # end

    # def stripe_subscription_created(event)
    #   stripe_subscription = event.data.object
    #   @customer = Effective::Customer.where(stripe_customer_id: stripe_subscription.customer).first

    #   if @customer.present?
    #     subscription = @customer.subscriptions.where(stripe_plan_id: stripe_subscription.plan.id).first_or_initialize

    #     subscription.stripe_subscription_id = stripe_subscription.id
    #     subscription.stripe_plan_id = (stripe_subscription.plan.id rescue nil)
    #     subscription.stripe_coupon_id = stripe_subscription.discount.coupon.id if (stripe_subscription.discount.present? rescue false)

    #     subscription.save!

    #     unless subscription.purchased?
    #       # Now we have to purchase it
    #       @order = Effective::Order.new(subscription, user: @customer.user)
    #       @order.purchase!(details: "Webhook #{event.id}", provider: 'stripe', validate: false)
    #     end
    #   end

    # end

    # def stripe_subscription_deleted(event)
    #   stripe_subscription = event.data.object
    #   @customer = Effective::Customer.where(stripe_customer_id: stripe_subscription.customer).first

    #   if @customer.present?
    #     @customer.subscriptions.find { |subscription| subscription.stripe_plan_id == stripe_subscription.plan.id }.try(:destroy)
    #     subscription_deleted_callback(event)
    #   end
    # end

    # def invoice_payment_succeeded(event)
    #   @customer = Effective::Customer.where(stripe_customer_id: event.data.object.customer).first

    #   check_for_subscription_renewal(event) if @customer.present?
    # end

    # def check_for_subscription_renewal(event)
    #   invoice_payment = event.data.object
    #   subscription_payments = invoice_payment.lines.select { |line_item| line_item.type == 'subscription' }

    #   if subscription_payments.present?
    #     customer = Stripe::Customer.retrieve(invoice_payment.customer)
    #     subscription_payments.each do |subscription_payment|
    #       subscription_renewed_callback(event) if stripe_subscription_renewed?(customer, subscription_payment)
    #     end
    #   end
    # end

    # def stripe_subscription_renewed?(customer, subscription_payment)
    #   subscription = customer.subscriptions.retrieve(subscription_payment.id) rescue nil  # API client raises error when object not found
    #   subscription.present? && subscription.status == 'active' && subscription.start < (subscription_payment.period.start - 1.day)
    # end

    # def subscription_deleted_callback(_event)
    #   # Can be overridden in Effective::WebhooksController within a Rails application
    # end

    # def subscription_renewed_callback(_event)
    #   # Can be overridden in Effective::WebhooksController within a Rails application
    # end
  end
end
