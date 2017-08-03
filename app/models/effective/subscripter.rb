# Form object to select a subscription, and to handle all the logic

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :user, :subscribable
    attr_accessor :stripe_plan_id, :stripe_token

    validates :user, presence: true
    validates :subscribable, presence: true
    validates :stripe_plan_id, inclusion: { in: EffectiveOrders.stripe_plans.keys, message: 'unknown plan' }

    # validate(if: -> { stripe_plan_id && subscribable && plan.present? }) do
    #   if plan[:amount] > 0 && customer.stripe_active_card.blank? && stripe_token.blank?
    #     self.errors.add(:customer, 'customer payment token required for non-free plan')
    #   end
    # end

    def save!
      raise 'is invalid' unless valid?
      build && subscribable.save!
    end

    def subscribe!(stripe_plan_id)
      self.stripe_plan_id = stripe_plan_id
      save!
    end

    def current_plan
      (subscribable.subscription.plan if subscribable.subscription)
    end

    def plan
      EffectiveOrders.stripe_plans[stripe_plan_id]
    end

    private

    def build
      return false unless subscribable && user && (plan || stripe_token)

      # Build the subscription
      subscription = subscribable.subscription || subscribable.build_subscription(customer: user.customer)

      # Build the customer
      customer = subscription.customer || subscription.build_customer(user: user)

      # Make sure a new customer has the correct subscriptions data
      customer.subscriptions << subscription unless customer.subscriptions.find { |sub| sub.subscribable == subscribable }

      # Assign stripe plan id
      subscription.stripe_plan_id = plan[:id] if plan

      # Assign stripe token - make sure we update the customer
      customer.stripe_source = stripe_token if stripe_token

      # Return the subscription
      subscription
    end

  end
end
