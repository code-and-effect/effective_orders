module Effective
  class OrdersMailer < EffectiveOrders.parent_mailer_class
    include EffectiveMailer

    helper EffectiveOrdersHelper

    def order_receipt_to_admin(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      subject = subject_for(__method__, "Order Receipt: ##{@order.to_param}", resource, opts)
      headers = headers_for(resource, opts)

      mail(to: mailer_admin, subject: subject, **headers)
    end

    def order_receipt_to_buyer(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      subject = subject_for(__method__, "Order Receipt: ##{@order.to_param}", resource, opts)
      headers = headers_for(resource, opts)

      mail(to: @order.email, cc: @order.cc.presence, subject: subject, **headers)
    end

    # This is sent when an admin creates a new order or /admin/orders/new
    # Or when Pay by Cheque or Pay by Phone (deferred payments)
    # Or uses the order action Send Payment Request
    def payment_request_to_buyer(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      subject = subject_for(__method__, "Payment request - Order ##{@order.to_param}", resource, opts)
      headers = headers_for(resource, opts)

      mail(to: @order.email, cc: @order.cc.presence, subject: subject, **headers)
    end

    # This is sent when someone chooses to Pay by Cheque
    def pending_order_invoice_to_buyer(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      subject = subject_for(__method__, "Pending Order: ##{@order.to_param}", resource, opts)
      headers = headers_for(resource, opts)

      mail(to: @order.email, cc: @order.cc.presence, subject: subject, **headers)
    end

    # This is sent to admin when someone Accepts Refund
    def refund_notification_to_admin(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      subject = subject_for(__method__, "New Refund: ##{@order.to_param}", resource, opts)
      headers = headers_for(resource, opts)

      mail(to: mailer_admin, subject: subject, **headers)
    end

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
