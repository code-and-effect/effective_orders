# This is an object for the stripe form

module Effective
  class StripeCharge
    extend ActiveModel::Naming
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveRecord::Reflection

    # These are pretend values we just have here so we can display a form for them.
    # Simpleform needs the attribute to exist in order to use = f.input
    # We use the Stripe.js to validate these, and set the token.
    # We never transmit this information over the internet.
    attr_accessor :number, :cvc, :exp_month, :exp_year

    attr_accessor :token, :order, :effective_order_id # These are the actual values we receive and need to validate.

    validates_presence_of :token,
      :if => Proc.new { |stripe_charge| stripe_charge.order.buyer.stripe_active_card.blank? rescue true },
      :message => 'Unable to process with existing card.  Please enter a new credit card.'

    def initialize(params = {})
      if params.kind_of?(Effective::Order)
        @effective_order_id = params.id
      else
        params.each { |k, v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
      end
    end

    def persisted?
      false
    end

    def save
      valid?
    end

  end
end
