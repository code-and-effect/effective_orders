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
  end

  module ClassMethods
  end

  # # 'Monthly basic'
  # def subscribe_to!(plan)
  #   raise "invalid plan: #{plan}" unless EffectiveOrders.stripe_plans.keys.include?(plan)

  #   cust = customer || build_customer
  #   subscription = subscriptions.find { |subscription| subscription.plan == 'subscription' }

  # end

  # Regular instance methods

end

