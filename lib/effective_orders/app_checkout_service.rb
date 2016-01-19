module EffectiveOrders
  class AppCheckoutService
    def self.call(order:)
      new(order).tap(&:call)
    end

    attr_reader :order

    def initialize(order)
      @order = order
    end

    def call
    end

    def success?
      raise NotImplementedError, "overwrite the `success?` instance method in #{self.class}"
    end

    # A Hash or easily serializable object like a String
    def payment_details
    end
  end
end

