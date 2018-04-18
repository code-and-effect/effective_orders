module Effective
  class OrdersMailer < ActionMailer::Base
    helper EffectiveOrdersHelper

    layout EffectiveOrders.mailer[:layout].presence || 'effective_orders_mailer_layout'

    def order_receipt_to_admin(order_param)
      return true unless EffectiveOrders.mailer[:send_order_receipt_to_admin]

      @order = (order_param.kind_of?(Effective::Order) ? order_param : Effective::Order.find(order_param))

      mail(
        to: EffectiveOrders.mailer[:admin_email],
        from: EffectiveOrders.mailer[:default_from],
        subject: subject_for_order_receipt_to_admin(@order)
      )
    end

    def order_receipt_to_buyer(order_param)  # Buyer
      return true unless EffectiveOrders.mailer[:send_order_receipt_to_buyer]

      @order = (order_param.kind_of?(Effective::Order) ? order_param : Effective::Order.find(order_param))

      mail(
        to: @order.user.email,
        from: EffectiveOrders.mailer[:default_from],
        subject: subject_for_order_receipt_to_buyer(@order)
      )
    end

    def order_receipt_to_seller(order_param, seller, order_items)
      return true unless EffectiveOrders.mailer[:send_order_receipt_to_seller]

      @order = (order_param.kind_of?(Effective::Order) ? order_param : Effective::Order.find(order_param))
      @user = seller.user
      @order_items = order_items
      @subject = subject_for_order_receipt_to_seller(@order, @order_items, seller.user)

      mail(
        to: @user.email,
        from: EffectiveOrders.mailer[:default_from],
        subject: @subject
      )
    end

    # This is sent when an admin creates a new order or /admin/orders/new
    # Or uses the order action Send Payment Request
    def payment_request_to_buyer(order_param)
      return true unless EffectiveOrders.mailer[:send_payment_request_to_buyer]

      @order = (order_param.kind_of?(Effective::Order) ? order_param : Effective::Order.find(order_param))

      mail(
        to: @order.user.email,
        from: EffectiveOrders.mailer[:default_from],
        subject: subject_for_payment_request_to_buyer(@order)
      )
    end

    # This is sent when someone chooses to Pay by Cheque
    def pending_order_invoice_to_buyer(order_param)
      return true unless EffectiveOrders.mailer[:send_pending_order_invoice_to_buyer]

      @order = (order_param.kind_of?(Effective::Order) ? order_param : Effective::Order.find(order_param))

      mail(
        to: @order.user.email,
        from: EffectiveOrders.mailer[:default_from],
        subject: subject_for_pending_order_invoice_to_buyer(@order)
      )
    end

    # Sent by the invoice.payment_succeeded webhook event
    def subscription_payment_succeeded(customer_param)
      return true unless EffectiveOrders.mailer[:send_subscription_payment_succeeded]

      @customer = (customer_param.kind_of?(Effective::Customer) ? customer_param : Effective::Customer.find(customer_param))

      mail(
        to: @customer.user.email,
        from: EffectiveOrders.mailer[:default_from],
        subject: subject_for_subscription_payment_succeeded(@customer)
      )
    end

    # Sent by the invoice.payment_failed webhook event
    def subscription_payment_failed(customer_param)
      return true unless EffectiveOrders.mailer[:send_subscription_payment_failed]

      @customer = (customer_param.kind_of?(Effective::Customer) ? customer_param : Effective::Customer.find(customer_param))

      mail(
        to: @customer.user.email,
        from: EffectiveOrders.mailer[:default_from],
        subject: subject_for_subscription_payment_failed(@customer)
      )
    end

    # Sent by the invoice.payment_failed webhook event
    def subscription_canceled(customer_param)
      return true unless EffectiveOrders.mailer[:send_subscription_canceled]

      @customer = (customer_param.kind_of?(Effective::Customer) ? customer_param : Effective::Customer.find(customer_param))

      mail(
        to: @customer.user.email,
        from: EffectiveOrders.mailer[:default_from],
        subject: subject_for_subscription_canceled(@customer)
      )
    end

    # Sent by the effective_orders:notify_trial_users rake task.
    def subscription_trial_expiring(subscribable)
      return true unless EffectiveOrders.mailer[:send_subscription_trial_expiring]

      @subscribable = subscribable

      mail(
        to: @subscribable.subscribable_buyer.email,
        from: EffectiveOrders.mailer[:default_from],
        subject: subject_for_subscription_trial_expiring(@subscribable)
      )
    end

    # Sent by the effective_orders:notify_trial_users rake task.
    def subscription_trial_expired(subscribable)
      return true unless EffectiveOrders.mailer[:send_subscription_trial_expired]

      @subscribable = subscribable

      mail(
        to: @subscribable.subscribable_buyer.email,
        from: EffectiveOrders.mailer[:default_from],
        subject: subject_for_subscription_trial_expired(@subscribable)
      )
    end

    def order_error(order: nil, error: nil, to: nil, from: nil, subject: nil, template: 'order_error')
      if order.present?
        @order = (order.kind_of?(Effective::Order) ? order : Effective::Order.find(order))
        @subject = (subject || "An error occurred with order: ##{@order.try(:to_param)}")
      else
        @subject = (subject || "An order error occurred with an unknown order")
      end

      @error = error.to_s

      mail(
        to: (to || EffectiveOrders.mailer[:admin_email]),
        from: (from || EffectiveOrders.mailer[:default_from]),
        subject: prefix_subject(@subject),
      ) do |format|
        format.html { render(template) }
      end
    end

    private

    def subject_for_order_receipt_to_admin(order)
      string_or_callable = EffectiveOrders.mailer[:subject_for_order_receipt_to_admin]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || "Order Receipt: ##{order.to_param}")
    end

    def subject_for_order_receipt_to_buyer(order)
      string_or_callable = EffectiveOrders.mailer[:subject_for_order_receipt_to_buyer]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || "Order Receipt: ##{order.to_param}")
    end

    def subject_for_order_receipt_to_seller(order, order_items, seller)
      string_or_callable = EffectiveOrders.mailer[:subject_for_order_receipt_to_seller]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, order_items, seller, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || "#{order_items.length} of your products #{order_items.length > 1 ? 'have' : 'has'} been purchased")
    end

    def subject_for_payment_request_to_buyer(order)
      string_or_callable = EffectiveOrders.mailer[:subject_for_payment_request_to_buyer]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || "Request for Payment: Invoice ##{order.to_param}")
    end

    def subject_for_pending_order_invoice_to_buyer(order)
      string_or_callable = EffectiveOrders.mailer[:subject_for_pending_order_invoice_to_buyer]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || "Pending Order: ##{order.to_param}")
    end

    def subject_for_subscription_payment_succeeded(customer)
      string_or_callable = EffectiveOrders.mailer[:subject_for_subscription_payment_succeeded]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || 'Thank you for your payment')
    end

    def subject_for_subscription_payment_failed(customer)
      string_or_callable = EffectiveOrders.mailer[:subject_for_subscription_payment_failed]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || 'Payment failed - please update your card details')
    end

    def subject_for_subscription_canceled(customer)
      string_or_callable = EffectiveOrders.mailer[:subject_for_subscription_canceled]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || 'Subscription canceled')
    end

    def subject_for_subscription_trial_expiring(customer)
      string_or_callable = EffectiveOrders.mailer[:subject_for_subscription_trial_expiring]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || 'Trial expiring soon')
    end

    def subject_for_subscription_trial_expired(customer)
      string_or_callable = EffectiveOrders.mailer[:subject_for_subscription_trial_expired]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || 'Trial expired')
    end

    def prefix_subject(text)
      prefix = (EffectiveOrders.mailer[:subject_prefix].to_s rescue '')
      prefix.present? ? (prefix.chomp(' ') + ' ' + text) : text
    end
  end
end
