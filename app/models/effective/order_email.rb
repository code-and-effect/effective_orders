# frozen_string_literal: true
# a PORO to handle all the email logic for an order

module Effective
  class OrderEmail
    attr_accessor :order

    def initialize(order)
      raise('expected an Effective::Order') unless order.kind_of?(Effective::Order)
      @order = order
    end

    # Just to the purchaser. Not everyone.
    def to
      order.emails.first
    end

    def cc
      order.cc.presence
    end

    def category
      return :pending if order.pending? || order.confirmed?
      return :declined if order.declined?
      return :voided if order.voided?

      if event.present? && (order.purchased? || order.deferred?)
        return :event_confirmation 
      end

      if order.deferred?
        return :deferred_cheque if order.payment_provider == 'cheque'
        return :deferred_credit_card if order.payment_provider == 'deluxe_delayed'
        return :deferred_phone if order.payment_provider == 'phone'
        return :deferred_etransfer if order.payment_provider == 'etransfer'
      end

      if order.purchased?
        return :refund if order.refund?
        return :purchased
      end
    end

    def subject
      case category
        when :pending then return("Order Receipt: ##{order.to_param}")
        when :declined then return("Order Declined: ##{order.to_param}")
      end

      if event.present? && order.purchased_or_deferred?
        return "Confirmation - #{event}" if event_none_waitlisted?
        return "Confirmation + Waitlist - #{event}" if event_some_waitlisted?
        return "Waitlist - #{event}" if event_all_waitlisted?
      end

      # Fallback
      "Order: ##{order.to_param}"
    end

    def event
      order.purchasables.find { |purchasable| purchasable.kind_of?(Effective::EventRegistrant) }.try(:event)
    end

    def event_registrants
      order.purchasables.select { |purchasable| purchasable.kind_of?(Effective::EventRegistrant) }
    end

    def event_addons
      order.purchasables.select { |purchasable| purchasable.kind_of?(Effective::EventAddon) }
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
