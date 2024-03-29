# New workflow is:
# customer.updated
# customer.created
# customer.subscription.created
# customer.updated
# customer.source.created
# charge.succeeded
# invoice.created
# invoice.payment_succeeded

module Effective
  class WebhooksController < ApplicationController
    protect_from_forgery except: [:stripe]
    skip_authorization_check if defined?(CanCan)

    after_action :run_subscribable_buyer_callbacks!

    def stripe
      @event = EffectiveOrders.with_stripe { ::Stripe::Webhook.construct_event(request.body.read, request.env['HTTP_STRIPE_SIGNATURE'], EffectiveOrders.subscriptions[:webhook_secret]) rescue nil }

      (head(:ok) and return) if request.get? && @event.blank?
      (head(:bad_request) and return) unless @event

      unless EffectiveOrders.subscriptions[:ignore_livemode]
        (head(:bad_request) and return) if (params[:livemode] == false && Rails.env.production?)
      end

      Rails.logger.info "[STRIPE] webhook received: #{@event.type} for #{customer || 'no customer'}"

      Effective::Customer.transaction do
        case @event.type
        # when 'customer.created'
        # when 'customer.updated'
        # when 'customer.source.created'
        # when 'customer.source.deleted'
        # when 'customer.subscription.created'
        # when 'customer.subscription.updated'
        # when 'invoice.created'
        # when 'invoice.payment_succeeded'
        # when 'invoiceitem.created'
        # when 'invoiceitem.updated'
        # when 'charge.succeeded'
        # when 'charge.failed' # Card declined. 4000 0000 0000 0341

        when 'invoice.payment_succeeded'
          subscriptions.each { |subscription| subscription.update!(status: EffectiveOrders::ACTIVE) }
          send_email(:subscription_payment_succeeded, customer)
        when 'invoice.payment_failed'
          subscriptions.each { |subscription| subscription.update!(status: EffectiveOrders::PAST_DUE) }
          send_email(:subscription_payment_failed, customer)
        when 'customer.subscription.deleted'
          subscriptions.each { |subscription| subscription.destroy! }
          send_email(:subscription_canceled, customer)
        when 'customer.subscription.created'
          send_email(:subscription_created, customer)
        when 'customer.subscription.updated'
          send_email(:subscription_updated, customer)
        else
          Rails.logger.info "[STRIPE] successful event: #{@event.type}. Nothing to do."
        end
      end

      head(:ok)
    end

    private

    def customer
      return unless @event.respond_to?(:data)

      @customer ||= (
        stripe_customer_id = @event.data.object.customer if @event.data.object.respond_to?(:customer)
        stripe_customer_id = @event.data.object.id if @event.data.object.object == 'customer'

        Effective::Customer.where(stripe_customer_id: stripe_customer_id || 'none').first
      )
    end

    def subscriptions
      customer.subscriptions.select { |subscription| stripe_plan_ids.include?(subscription.stripe_plan_id) }
    end

    def stripe_plan_ids
      return unless @event.respond_to?(:data)

      @stripe_plan_ids ||= begin
        object = @event.data.object
        lines = object.respond_to?(:lines) ? object.lines : object.items
        lines.map { |line| line.plan.id }
      end
    end

    def send_email(email, customer)
      return unless EffectiveOrders.send_subscription_events

      EffectiveOrders.send_email(email, customer)
      EffectiveOrders.send_email(:subscription_event_to_admin, email.to_s, customer)
    end

    def run_subscribable_buyer_callbacks!
      return true if (@event.blank? || @customer.blank?)

      name = ('after_' + @event.type.to_s.gsub('.', '_')).to_sym
      buyer = @customer.user

      buyer.public_send(name, @event) if buyer.respond_to?(name)

      true
    end

  end
end
