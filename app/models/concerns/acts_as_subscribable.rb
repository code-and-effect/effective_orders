module ActsAsSubscribable
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_subscribable(*options)
      @acts_as_subscribable = options || []
      include ::ActsAsSubscribable
    end
  end

  included do
    has_one :customer, as: :buyer, class_name: 'Effective::Customer'
    has_many :subscriptions, as: :subscribable, class_name: 'Effective::Subscription'

    accepts_nested_attributes_for :customer
    accepts_nested_attributes_for :subscriptions
  end

  module ClassMethods
  end

  def subscribe_to!(name)
    plan = EffectiveOrders.stripe_plans[name.to_s] || raise("unknown stripe plan: #{name}")
    error = nil

    Effective::Subscription.transaction do
      begin
        # Create the customer
        build_customer(buyer: self) unless customer.present?

        if customer.stripe_customer_id.blank? && plan[:amount] > 0
          raise "unable to subscribe to #{plan[:name]}. Subscribing to a plan with amount > 0 requires a stripe customer token"
        end

        customer.save!

        # Create the subscription
        subscriptions.build(customer: customer, subscribable: self, stripe_plan_id: plan[:id]).save!

        return true
      rescue => e
        error = e.message
        raise ::ActiveRecord::Rollback
      end
    end

    raise "unable to subscribe to #{name}: #{error}"
  end

  def subcription(name)
    plan = EffectiveOrders.stripe_plans[name.to_s] || raise("unknown stripe plan: #{name}")
    subscriptions.find { |subscription| subscription.stripe_plan_id == plan[:id] }
  end

  def subscribed_to?(name)
    subcription(name).present?
  end

end

