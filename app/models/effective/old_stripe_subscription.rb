# This is an object for the subscriptions stripe form

module Effective
  class StripeSubscription
    extend ActiveModel::Naming
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveRecord::Reflection
    
    attr_accessor :plan, :token, :coupon # For our form

    validates_presence_of :plan, :token

    def initialize(params = {})
      params.each { |k, v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
    end

    def persisted?
      false
    end

  end
end
