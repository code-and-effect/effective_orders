module Effective
  class OrdersMailer < EffectiveOrders.parent_mailer_class
    default from: -> { EffectiveOrders.mailer_sender }
    layout -> { EffectiveOrders.mailer_layout }

    helper EffectiveOrdersHelper

    def order_receipt_to_admin(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      @subject = "Order Receipt: ##{@order.to_param}"

      mail(to: EffectiveOrders.mailer_admin, subject: @subject, **headers_for(resource, opts))
    end

    def order_receipt_to_buyer(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      @subject = "Order Receipt: ##{@order.to_param}"

      mail(to: @order.email, cc: @order.cc.presence, subject: @subject, **headers_for(resource, opts))
    end

    # This is sent when an admin creates a new order or /admin/orders/new
    # Or when Pay by Cheque or Pay by Phone (deferred payments)
    # Or uses the order action Send Payment Request
    def payment_request_to_buyer(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      @subject = "Payment request - Order ##{@order.to_param}"

      mail(to: @order.email, cc: @order.cc.presence, subject: @subject, **headers_for(resource, opts))
    end

    # This is sent when someone chooses to Pay by Cheque
    def pending_order_invoice_to_buyer(resource, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      @subject = "Pending Order: ##{@order.to_param}"

      mail(to: @order.email, cc: @order.cc.presence, subject: @subject, **headers_for(resource, opts))
    end

    # This is sent to admin when someone Accepts Refund
    def refund_notification_to_admin(order, opts = {})
      raise('expected an Effective::Order') unless resource.kind_of?(Effective::Order)

      @order = resource
      @subject = "New Refund: ##{@order.to_param}"

      mail(to: EffectiveOrders.mailer_admin, subject: @subject, **headers_for(resource, opts))
    end

    # Sent by the invoice.payment_succeeded webhook event
    def subscription_payment_succeeded(resource, opts = {})
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @customer = resource
      @subject = 'Thank you for your payment'

      mail(to: @customer.user.email, subject: @subject, **headers_for(resource, opts))
    end

    # Sent by the invoice.payment_failed webhook event
    def subscription_payment_failed(resource, opts = {})
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @customer = resource
      @subject = 'Payment failed - please update your card details'

      mail(to: @customer.user.email, subject: @subject, **headers_for(resource, opts))
    end

    # Sent by the customer.subscription.created webhook event
    def subscription_created(resource, opts = {})
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @customer = resource
      @subject = 'New Subscription'

      mail(to: @customer.user.email, subject: @subject, **headers_for(resource, opts))
    end

    # Sent by the customer.subscription.updated webhook event
    def subscription_created(resource, opts = {})
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @customer = resource
      @subject = 'Subscription Changed'

      mail(to: @customer.user.email, subject: @subject, **headers_for(resource, opts))
    end

     # Sent by the invoice.payment_failed webhook event
     def subscription_canceled(resource, opts = {})
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @customer = resource
      @subject = 'Subscription canceled'

      mail(to: @customer.user.email, subject: @subject, **headers_for(resource, opts))
    end

    # Sent by the effective_orders:notify_trial_users rake task.
    def subscription_trialing(resource, opts = {})
      raise('expected a subscribable resource') unless resource.respond_to?(:subscribable_buyer)

      @subscribable = resource
      @subject = 'Trial is active'

      mail(to: @subscribable.subscribable_buyer.email, subject: @subject, **headers_for(resource, opts))
    end

    # Sent by the effective_orders:notify_trial_users rake task.
    def subscription_trial_expired(resource, opts = {})
      raise('expected a subscribable resource') unless resource.respond_to?(:subscribable_buyer)

      @subscribable = resource
      @subject = 'Trial expired'

      mail(to: @subscribable.subscribable_buyer.email, subject: @subject, **headers_for(resource, opts))
    end

    def subscription_event_to_admin(event, resource, opts = {})
      raise('expected an event') unless event.present?
      raise('expected an Effective::Customer') unless resource.kind_of?(Effective::Customer)

      @event = event
      @customer = resource
      @subject = "Subscription event - #{@event} - #{@customer}"

      mail(to: EffectiveOrders.mailer_admin, subject: @subject, **headers_for(resource, opts))
    end

    # This is only called by EffectiveQbSync
    def order_error(order: nil, error: nil, to: nil, from: nil, subject: nil, template: 'order_error')
      raise('expected an Effective::Order') unless order.kind_of?(Effective::Order)

      @order = order
      @error = error.to_s
      @subject = "An error occurred with order: ##{@order.to_param}"

      mail(
        to: (to || EffectiveOrders.mailer[:admin_email]),
        from: (from || EffectiveOrders.mailer_sender),
        subject: (subject || @subject)
      ) do |format|
        format.html { render(template) }
      end
    end

    protected

    def headers_for(resource, opts = {})
      resource.respond_to?(:log_changes_datatable) ? opts.merge(log: resource) : opts
    end

    def subject_for(order, action, fallback)
      subject = EffectiveOrders.mailer["subject_for_#{action}".to_sym]
      prefix = EffectiveOrders.mailer[:subject_prefix].to_s

      subject = self.instance_exec(order, &subject) if subject.respond_to?(:call)
      subject = subject.presence || fallback

      prefix.present? ? (prefix.chomp(' ') + ' ' + subject) : subject
    end

  end
end
