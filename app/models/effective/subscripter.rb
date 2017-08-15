# Form object to select a plan, and build the correct subscription and customer

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :user, :subscribable
    attr_accessor :stripe_plan_id, :stripe_token

    validates :user, presence: true
    validates :subscribable, presence: true
    validates :stripe_plan_id, inclusion: { allow_blank: true, in: EffectiveOrders.stripe_plans.keys, message: 'unknown plan' }

    # validate do
    #   self.errors.add(:base, 'oh man')
    # end

    # validate(if: -> { stripe_plan_id && subscribable && plan.present? }) do
    #   if plan[:amount] > 0 && customer.stripe_active_card.blank? && stripe_token.blank?
    #     self.errors.add(:customer, 'customer payment token required for non-free plan')
    #   end
    # end

    validate(if: -> { subscribable.present? }) do
      subscribable.errors.add(:subscripter, 'is invalid') if self.errors.present?
    end

    def current_plan
      return nil unless subscribable
      subscribable.subscription.blank? ? EffectiveOrders.stripe_blank_plan : subscribable.subscription.plan
    end

    def plan
      EffectiveOrders.stripe_plans[stripe_plan_id]
    end

    def save!
      return true if plan == EffectiveOrders.stripe_blank_plan # TODO Delete?

      raise 'is invalid' unless valid?
      build && customer.save!
    end

    def subscribe!(stripe_plan_id)
      self.stripe_plan_id = stripe_plan_id
      save!
    end

    def build(stripe_plan_id = nil)
      self.stripe_plan_id = stripe_plan_id if stripe_plan_id

      return false unless subscribable && user && (plan || stripe_token)

      # Assign stripe token
      customer.stripe_source = stripe_token if stripe_token

      # Assign stripe plan
      subscription.stripe_plan_id = plan[:id] if plan

      subscription
    end

    private

    def customer
      @customer ||= Effective::Customer.deep.where(user: user).first_or_initialize
    end

    def subscription
      @subscription ||= (
        customer.subscriptions.find { |sub| sub.subscribable == subscribable } ||
        customer.subscriptions.build(subscribable: subscribable)
      )
    end

  end
end
