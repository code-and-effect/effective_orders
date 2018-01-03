module ActsAsSubscribableBuyer
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_subscribable_buyer(*options)
      include ::ActsAsSubscribableBuyer
    end
  end

  included do
    has_one :customer, class_name: 'Effective::Customer'

    before_save(if: -> { persisted? && email_changed? && customer.present? }) do
      Rails.logger.info "STRIPE CUSTOMER EMAIL UPDATE: #{customer.stripe_customer_id}"
      customer.stripe_customer.email = email
      customer.stripe_customer.description = to_s
      throw :abort unless (customer.stripe_customer.save rescue false)
    end
  end

end

