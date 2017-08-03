# Form object to select a subscription, and to handle all the logic

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :user, :subscribable
    attr_accessor :stripe_plan_id, :stripe_token

    validates :user, presence: true
    validates :subscribable, presence: true
    validates :stripe_plan_id, presence: true, inclusion: { in: EffectiveOrders.stripe_plans.keys, message: 'unknown plan' }

    # validate(if: -> { stripe_plan_id && subscribable && plan.present? }) do
    #   if plan[:amount] > 0 && customer.stripe_active_card.blank? && stripe_token.blank?
    #     self.errors.add(:customer, 'customer payment token required for non-free plan')
    #   end
    # end

    # validate(if: -> { errors.blank? && stripe_plan_id.present? && subscribable.subscription.blank? }) do
    #   Rails.logger.info "OKAY WE ARE BUILDING"
    # end

    def build(stripe_plan_id)
      return false unless subscribable && user

      Rails.logger.info "BUILDING SUBSCRIPTION!!!"

      # Use or build customer
      customer = user.customer || user.build_customer

      # Use or build subscription
      subscription = customer.subscriptions.find { |sub| sub.subscribable == subscribable } || customer.subscriptions.build(subscribable: subscribable, customer: customer)

      # Assign Stripe Plan
      subscription.stripe_plan_id = stripe_plan_id

      # Make sure subscribable has the correct subscription applied
      subscribable.subscription = subscription
    end

    def save!
      raise 'is invalid' unless valid?

      return true if current_plan == plan # No work to be done

      Effective::Subscription.transaction do
        begin
          # Make sure an Effective::Customer exists
          customer = Effective::Customer.where(user: user).first_or_initialize
          customer.assign_card(stripe_token)

          # Create a subscription item
          subscription = customer.subscriptions.find { |sub| sub.subscribable == subscribable } || customer.subscriptions.build(subscribable: subscribable, customer: customer)
          subscription.stripe_plan_id = plan[:id]

          customer.save!

          return true
        rescue => e
          self.errors.add(:base, e.message)
          raise ::ActiveRecord::Rollback
        end
      end

      raise "unable to subscribe to #{plan[:id]}: #{errors.full_messages.to_sentence}"
    end

    def subscribe!(stripe_plan_id)
      self.stripe_plan_id = stripe_plan_id
      save!
    end

    def customer
      @customer ||= (subscribable.customer || subcsribable.build_customer(buyer: subscribable))
    end

    def current_plan
      (subscribable.subscription.plan if subscribable.subscription)
    end

    def plan
      EffectiveOrders.stripe_plans[stripe_plan_id]
    end

  end
end
