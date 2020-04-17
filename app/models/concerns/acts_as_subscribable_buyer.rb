module ActsAsSubscribableBuyer
  extend ActiveSupport::Concern

  module Base
    def acts_as_subscribable_buyer(*options)
      include ::ActsAsSubscribableBuyer
    end
  end

  included do
    has_one :customer, class_name: 'Effective::Customer'

    before_save(if: -> { persisted? && email_changed? && customer.present? }) do
      Rails.logger.info "[STRIPE] update customer: #{customer.stripe_customer_id}"
      customer.stripe_customer.email = email
      customer.stripe_customer.description = to_s
      throw :abort unless (customer.stripe_customer.save rescue false)
    end
  end

  module ClassMethods
    def after_invoice_payment_succeeded(&block)
      send :define_method, :after_invoice_payment_succeeded do |event| self.instance_exec(event, &block) end
    end

    def after_invoice_payment_failed(&block)
      send :define_method, :after_invoice_payment_failed do |event| self.instance_exec(event, &block) end
    end

    def after_customer_subscription_created(&block)
      send :define_method, :after_customer_subscription_created do |event| self.instance_exec(event, &block) end
    end

    def after_customer_subscription_updated(&block)
      send :define_method, :after_customer_subscription_updated do |event| self.instance_exec(event, &block) end
    end

    def after_customer_subscription_deleted(&block)
      send :define_method, :after_customer_subscription_deleted do |event| self.instance_exec(event, &block) end
    end

    def after_customer_updated(&block)
      send :define_method, :after_customer_updated do |event| self.instance_exec(event, &block) end
    end

  end

end

