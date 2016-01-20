module EffectiveOrders
  class AppCheckoutService
    def self.call(options = {})
      order = options[:order]
      new(order).tap(&:call)
    end

    attr_reader :order

    def initialize(order)
      @order = order
    end

    def call
      raise NotImplementedError, "overwrite the `call` instance method in #{self.class}"
    end

    def success?
      raise NotImplementedError, "overwrite the `success?` instance method in #{self.class}"
    end

    # A Hash or easily serializable object like a String
    def payment_details
    end
  end
end

