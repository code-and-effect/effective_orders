module Effective
  class OrdersMailer < EffectiveOrders.parent_mailer_class
    include EffectiveMailer

    helper EffectiveOrdersHelper
    helper EffectiveEventsHelper if defined?(EffectiveEventsHelper)

    # This is the new order email
    # It's sent from like 15 different places in 15 different ways
    # Has to be aware of events and registrations, applicants, renewals, etc
    # Has to be aware of deferred payments, delayed payments, requests for payment, purchased, declined etc
    def order_email(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      @order_email = Effective::OrderEmail.new(resource, opts)

      subject = subject_for(__method__, @order_email.subject, @order, opts)
      headers = headers_for(@order, opts)

      mail(to: @order_email.to, cc: @order_email.cc, subject: subject, **headers)
    end

    # Same as above but sent to admin
    def order_email_to_admin(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      @order_email = Effective::OrderEmail.new(resource)

      subject = subject_for(__method__, @order_email.subject, @order, opts)
      headers = headers_for(@order, opts)

      mail(to: mailer_admin, subject: subject, **headers)
    end

    # This is sent to admin when someone Accepts Refund
    def refund_notification_to_admin(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      subject = subject_for(__method__, "New Refund: ##{@order.to_param}", resource, opts)
      headers = headers_for(resource, opts)

      mail(to: mailer_admin, subject: subject, **headers)
    end

    #### OLD EMAILS ####

    # Sent by the invoice.payment_succeeded webhook event
    def subscription_payment_succeeded(resource, opts = {})
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @customer = resource
      subject = subject_for(__method__, 'Thank you for your payment', resource, opts)
      headers = headers_for(resource, opts)

      mail(to: @customer.user.email, subject: subject, **headers)
    end

    # Sent by the invoice.payment_failed webhook event
    def subscription_payment_failed(resource, opts = {})
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @customer = resource
      subject = subject_for(__method__, 'Payment failed - please update your card details', resource, opts)
      headers = headers_for(resource, opts)

      mail(to: @customer.user.email, subject: subject, **headers)
    end

    # Sent by the customer.subscription.created webhook event
    def subscription_created(resource, opts = {})
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @customer = resource
      subject = subject_for(__method__, 'New Subscription', resource, opts)
      headers = headers_for(resource, opts)

      mail(to: @customer.user.email, subject: subject, **headers)
    end

    # Sent by the customer.subscription.updated webhook event
    def subscription_updated(resource, opts = {})
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @customer = resource
      subject = subject_for(__method__, 'Subscription Changed', resource, opts)
      headers = headers_for(resource, opts)

      mail(to: @customer.user.email, subject: subject, **headers)
    end

     # Sent by the invoice.payment_failed webhook event
     def subscription_canceled(resource, opts = {})
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @customer = resource
      subject = subject_for(__method__, 'Subscription canceled', resource, opts)
      headers = headers_for(resource, opts)

      mail(to: @customer.user.email, subject: subject, **headers)
    end

    # Sent by the effective_orders:notify_trial_users rake task.
    def subscription_trialing(resource, opts = {})
      raise('expected a subscribable resource') unless resource.respond_to?(:subscribable_buyer)

      @subscribable = resource
      subject = subject_for(__method__, 'Trial is active', resource, opts)
      headers = headers_for(resource, opts)

      mail(to: @subscribable.subscribable_buyer.email, subject: subject, **headers)
    end

    # Sent by the effective_orders:notify_trial_users rake task.
    def subscription_trial_expired(resource, opts = {})
      raise('expected a subscribable resource') unless resource.respond_to?(:subscribable_buyer)

      @subscribable = resource
      subject = subject_for(__method__, 'Trial expired', resource, opts)
      headers = headers_for(resource, opts)

      mail(to: @subscribable.subscribable_buyer.email, subject: subject, **headers)
    end

    def subscription_event_to_admin(event, resource, opts = {})
      raise('expected an event') unless event.present?
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @event = event
      @customer = resource

      subject = subject_for(__method__, "Subscription event - #{@event} - #{@customer}", resource, opts)
      headers = headers_for(resource, opts)

      mail(to: mailer_admin, subject: subject, **headers)
    end

    # This is only called by EffectiveQbSync
    def order_error(order: nil, error: nil, to: nil, from: nil, subject: nil, template: 'order_error')
      raise('expected an Effective::Order') unless order.kind_of?(Effective::Order)

      @order = order
      @error = error.to_s
      opts = {}

      to ||= EffectiveOrders.mailer_admin
      from ||= EffectiveOrders.mailer_sender
      subject ||= subject_for(__method__,"An error occurred with order: ##{@order.to_param}", @order, opts)
      headers = headers_for(@order, opts)

      mail(to: to, from: from, subject: subject, **headers) do |format|
        format.html { render(template) }
      end
    end

  end
end
