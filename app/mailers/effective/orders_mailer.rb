module Effective
  class OrdersMailer < ActionMailer::Base
    default :from => EffectiveOrders.mailer[:default_from]

    def order_receipt_to_admin(order)
      @order = order
      mail(:to => EffectiveOrders.mailer[:admin_email], :subject => subject("Order ##{order.id} Receipt"))
    end

    def order_receipt_to_buyer(order)  # Buyer
      @order = order
      mail(:to => order.user.email, :subject => subject("Order ##{order.id} Receipt"))
    end

    def order_receipt_to_seller(order, seller, order_items)
      @order = order
      @user = seller.user
      @order_items = order_items
      @subject = "#{@order_items.count} of your products #{@order_items.count > 1 ? 'have' : 'has'} been purchased"

      mail(:to => @user.email, :subject => subject(@subject))
    end

    private

    def subject(text)
      prefix = (EffectiveOrders.mailer[:subject_prefix].to_s rescue '')
      prefix.present? ? (prefix.chomp(' ') + ' ' + text) : text
    end

  end
end

