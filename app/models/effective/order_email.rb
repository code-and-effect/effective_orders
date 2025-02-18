# frozen_string_literal: true
# a PORO to handle all the email logic for an order

module Effective
  class OrderEmail
    attr_accessor :order
    attr_accessor :opts

    def initialize(order, opts = {})
      raise('expected an Effective::Order') unless order.kind_of?(Effective::Order)
      raise('expected a Hash of options') unless opts.kind_of?(Hash)

      @order = order
      @opts = opts
    end

    # Just to the purchaser. Not everyone.
    def to
      return order.emails if payment_request?
      order.emails.first
    end

    def cc
      order.cc.presence
    end

    # The very first line of the email body
    def header
      if event.present? && order.purchased_or_deferred?
        return "Your tickets have been confirmed" if event_none_waitlisted?
        return "Some of your tickets have been confirmed, but some are on the waitlist" if event_some_waitlisted?
        return "Your tickets are on the waitlist" if event_all_waitlisted?
      end

      return "Request for Payment" if payment_request?
      return "Pending order created" if order.deferred?
      return "Your order has been successfully purchased" if order.purchased?
      return "Your order was declined by the payment processor" if order.declined?

      # Fallback
      "Order: ##{order.to_param}"
    end

    def subject
      if event.present? && order.purchased_or_deferred?
        return "Confirmation - #{event}" if event_none_waitlisted?
        return "Confirmation + Waitlist - #{event}" if event_some_waitlisted?
        return "Waitlist - #{event}" if event_all_waitlisted?
      end

      return "Payment Request - Order: ##{order.to_param}" if payment_request?
      return "Pending Order: ##{order.to_param}" if order.deferred?
      return "Declined Order: ##{order.to_param}" if order.declined?
      return "Order Receipt: ##{order.to_param}" if order.purchased?

      # Fallback
      "Order: ##{order.to_param}"
    end

    def payment_request?
      opts[:payment_request] == true
    end

    def event
      order.purchasables.find { |purchasable| purchasable.class.name == "Effective::EventRegistrant" }.try(:event)
    end

    def event_registration
      order.purchasables.find { |purchasable| purchasable.class.name == "Effective::EventRegistrant" }.try(:event_registration)
    end

    def event_registrants
      order.purchasables.select { |purchasable| purchasable.class.name == "Effective::EventRegistrant" }
    end

    def event_addons
      order.purchasables.select { |purchasable| purchasable.class.name == "Effective::EventAddon" }
    end

    def event_none_waitlisted?
      return false unless event_registrants.present?
      event_registrants.none? { |er| er.waitlisted_not_promoted? }
    end

    def event_some_waitlisted?
      return false unless event_registrants.present?

      event_registrants.find { |er| er.waitlisted_not_promoted? }.present? && 
      event_registrants.find { |er| !er.waitlisted_not_promoted? }.present?
    end

    def event_all_waitlisted?
      return false unless event_registrants.present?
      event_registrants.all? { |er| er.waitlisted_not_promoted? }
    end

  end
end
