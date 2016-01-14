module Effective
  class OrdersMailer < ActionMailer::Base
    helper EffectiveOrdersHelper
    default :from => EffectiveOrders.mailer[:default_from]

    layout EffectiveOrders.mailer[:layout].presence || 'effective_orders_mailer_layout'

    def order_receipt_to_admin(order)
      @order = order
      mail(:to => EffectiveOrders.mailer[:admin_email], :subject => receipt_to_admin_subject(order))
    end

    def order_receipt_to_buyer(order)  # Buyer
      @order = order
      mail(:to => order.user.email, :subject => receipt_to_buyer_subject(order))
    end

    def payment_request_to_buyer(order)
      @order = order
      mail(:to => order.user.email, :subject => invoice_to_buyer_subject(order))
    end

    def order_receipt_to_seller(order, seller, order_items)
      @order = order
      @user = seller.user
      @order_items = order_items
      @subject = receipt_to_seller_subject(order, order_items, seller.user)

      mail(:to => @user.email, :subject => @subject)
    end

    private

    def receipt_to_admin_subject(order)
      string_or_callable = EffectiveOrders.mailer[:subject_for_admin_receipt]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || "Order ##{order.to_param} Receipt")
    end

    def receipt_to_buyer_subject(order)
      string_or_callable = EffectiveOrders.mailer[:subject_for_buyer_receipt]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || "Order ##{order.to_param} Receipt")
    end

    def invoice_to_buyer_subject(order)
      string_or_callable = EffectiveOrders.mailer[:subject_for_buyer_invoice]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || "Order ##{order.to_param} Invoice")
    end

    def receipt_to_seller_subject(order, order_items, seller)
      string_or_callable = EffectiveOrders.mailer[:subject_for_seller_receipt]

      if string_or_callable.respond_to?(:call) # This is a Proc or a function, not a string
        string_or_callable = self.instance_exec(order, order_items, seller, &string_or_callable)
      end

      prefix_subject(string_or_callable.presence || "#{order_items.length} of your products #{order_items.length > 1 ? 'have' : 'has'} been purchased")
    end

    def prefix_subject(text)
      prefix = (EffectiveOrders.mailer[:subject_prefix].to_s rescue '')
      prefix.present? ? (prefix.chomp(' ') + ' ' + text) : text
    end
  end
end
