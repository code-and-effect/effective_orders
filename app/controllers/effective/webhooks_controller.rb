module Effective
  class WebhooksController < ApplicationController
    protect_from_forgery except: [:stripe]
    skip_authorization_check if defined?(CanCan)

    def stripe
      @event = (Stripe::Webhook.construct_event(request.body.read, request.env['HTTP_STRIPE_SIGNATURE'], EffectiveOrders.subscription[:webhook_secret]) rescue nil)
      (head(:bad_request) and return) unless @event

      unless EffectiveOrders.subscriptions[:ignore_livemode]
        (head(:bad_request) and return) if (params[:livemode] == false && Rails.env.production?)
      end

      Rails.logger.info "STRIPE WEBHOOK: #{@event.type}"

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
          customer = Effective::Customer.where(stripe_customer_id: @event.data.object.customer).first!
          customer.update_attributes!(status: EffectiveOrders::ACTIVE)

          send_email(:subscription_payment_succeeded, customer)
        when 'invoice.payment_failed'
          customer = Effective::Customer.where(stripe_customer_id: @event.data.object.customer).first!
          customer.update_attributes!(status: EffectiveOrders::PAST_DUE)

          send_email(:subscription_payment_failed, customer)
        when 'customer.subscription.deleted'
          customer = Effective::Customer.where(stripe_customer_id: @event.data.object.customer).first!
          customer.update_attributes!(stripe_subscription_id: nil, status: nil, active_card: nil)
          customer.subscriptions.delete_all

          send_email(:subscription_canceled, customer)
        else
          Rails.logger.info "[STRIPE WEBHOOK] Unhandled event type #{@event.type}"
        end
      end

      head(:ok)
    end

    private

    def send_email(email, *mailer_args)
      Effective::OrdersMailer.public_send(email, *mailer_args).public_send(EffectiveOrders.mailer[:deliver_method])
    end

  end
end
