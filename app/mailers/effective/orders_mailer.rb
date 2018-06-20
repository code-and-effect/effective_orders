module Effective
  class OrdersMailer < ActionMailer::Base
    default from: EffectiveOrders.mailer[:default_from]

    helper EffectiveOrdersHelper
    layout EffectiveOrders.mailer[:layout].presence || 'effective_orders_mailer_layout'

    def order_receipt_to_admin(order_param)
      return true unless EffectiveOrders.mailer[:send_order_receipt_to_admin]

      @order = (order_param.kind_of?(Effective::Order) ? order_param : Effective::Order.find(order_param))
      @user = @order.user

      @subject = subject_for(@order, :order_receipt_to_admin, "Order Receipt: ##{@order.to_param}")

      mail(to: EffectiveOrders.mailer[:admin_email], from: EffectiveOrders.mailer[:default_from], subject: @subject)
    end

    def order_receipt_to_buyer(order_param)  # Buyer
      return true unless EffectiveOrders.mailer[:send_order_receipt_to_buyer]

      @order = (order_param.kind_of?(Effective::Order) ? order_param : Effective::Order.find(order_param))
      @user = @order.user

      @subject = subject_for(@order, :order_receipt_to_buyer, "Order Receipt: ##{@order.to_param}")

      mail(to: @order.user.email, subject: @subject)
    end

    # This is sent when an admin creates a new order or /admin/orders/new
    # Or uses the order action Send Payment Request
    def payment_request_to_buyer(order_param)
      return true unless EffectiveOrders.mailer[:send_payment_request_to_buyer]

      @order = (order_param.kind_of?(Effective::Order) ? order_param : Effective::Order.find(order_param))
      @user = @order.user

      @subject = subject_for(@order, :payment_request_to_buyer, "Request for Payment: Invoice ##{@order.to_param}")

      mail(to: @order.user.email, subject: @subject)
    end

    # This is sent when someone chooses to Pay by Cheque
    def pending_order_invoice_to_buyer(order_param)
      return true unless EffectiveOrders.mailer[:send_pending_order_invoice_to_buyer]

      @order = (order_param.kind_of?(Effective::Order) ? order_param : Effective::Order.find(order_param))
      @user = @order.user

      @subject = subject_for(@order, :pending_order_invoice_to_buyer, "Pending Order: ##{@order.to_param}")

      mail(to: @order.user.email, subject: @subject)
    end

    # Sent by the invoice.payment_succeeded webhook event
    def subscription_payment_succeeded(customer_param)
      return true unless EffectiveOrders.mailer[:send_subscription_payment_succeeded]

      @customer = (customer_param.kind_of?(Effective::Customer) ? customer_param : Effective::Customer.find(customer_param))
      @subscriptions = @customer.subscriptions
      @user = @customer.user

      @subject = subject_for(@customer, :subscription_payment_succeeded, 'Thank you for your payment')

      mail(to: @customer.user.email, subject: @subject)
    end

    # Sent by the invoice.payment_failed webhook event
    def subscription_payment_failed(customer_param)
      return true unless EffectiveOrders.mailer[:send_subscription_payment_failed]

      @customer = (customer_param.kind_of?(Effective::Customer) ? customer_param : Effective::Customer.find(customer_param))
      @subscriptions = @customer.subscriptions
      @user = @customer.user

      @subject = subject_for(@customer, :subscription_payment_failed, 'Payment failed - please update your card details')

      mail(to: @customer.user.email, subject: @subject)
    end

    # Sent by the customer.subscription.created webhook event
    def subscription_created(customer_param)
      return true unless EffectiveOrders.mailer[:send_subscription_created]

      @customer = (customer_param.kind_of?(Effective::Customer) ? customer_param : Effective::Customer.find(customer_param))
      @subscriptions = @customer.subscriptions
      @user = @customer.user

      @subject = subject_for(@customer, :subscription_created, 'New Subscription')

      mail(to: @customer.user.email, subject: @subject)
    end

    # Sent by the customer.subscription.updated webhook event
    def subscription_updated(customer_param)
      return true unless EffectiveOrders.mailer[:send_subscription_updated]

      @customer = (customer_param.kind_of?(Effective::Customer) ? customer_param : Effective::Customer.find(customer_param))
      @subscriptions = @customer.subscriptions
      @user = @customer.user

      @subject = subject_for(@customer, :subscription_updated, 'Subscription Changed')

      mail(to: @customer.user.email, subject: @subject)
    end

    # Sent by the invoice.payment_failed webhook event
    def subscription_canceled(customer_param)
      return true unless EffectiveOrders.mailer[:send_subscription_canceled]

      @customer = (customer_param.kind_of?(Effective::Customer) ? customer_param : Effective::Customer.find(customer_param))
      @subscriptions = @customer.subscriptions
      @user = @customer.user

      @subject = subject_for(@customer, :subscription_canceled, 'Subscription canceled')

      mail(to: @customer.user.email, subject: @subject)
    end

    # Sent by the effective_orders:notify_trial_users rake task.
    def subscription_trialing(subscribable)
      return true unless EffectiveOrders.mailer[:send_subscription_trialing]

      @subscribable = subscribable
      @user = @subscribable.subscribable_buyer

      @subject = subject_for(@customer, :subscription_trialing, 'Trial is active')

      mail(to: @subscribable.subscribable_buyer.email, subject: @subject)
    end

    # Sent by the effective_orders:notify_trial_users rake task.
    def subscription_trial_expired(subscribable)
      return true unless EffectiveOrders.mailer[:send_subscription_trial_expired]

      @subscribable = subscribable
      @user = @subscribable.subscribable_buyer

      @subject = subject_for(@customer, :subscription_trial_expired, 'Trial expired')

      mail(to: @subscribable.subscribable_buyer.email, subject: @subject)
    end

    def order_error(order: nil, error: nil, to: nil, from: nil, subject: nil, template: 'order_error')
      @order = (order.kind_of?(Effective::Order) ? order : Effective::Order.find(order))
      @error = error.to_s

      @subject = subject_for(@order, :error, "An error occurred with order: ##{@order.try(:to_param)}")

      mail(
        to: (to || EffectiveOrders.mailer[:admin_email]),
        from: (from || EffectiveOrders.mailer[:default_from]),
        subject: (subject || @subject)
      ) do |format|
        format.html { render(template) }
      end
    end

    private

    def subject_for(order, action, fallback)
      subject = EffectiveOrders.mailer["subject_for_#{action}".to_sym]
      prefix = EffectiveOrders.mailer[:subject_prefix].to_s

      subject = self.instance_exec(order, &subject) if subject.respond_to?(:call)
      subject = subject.presence || fallback

      prefix.present? ? (prefix.chomp(' ') + ' ' + subject) : subject
    end

  end
end
