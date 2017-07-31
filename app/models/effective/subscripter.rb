# Form object to select a subscription, and to handle all the logic

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :subscribable, :stripe_plan_id, :plan

    validates :subscribable, presence: true
    validates :plan, inclusion: { allow_nil: true, in: EffectiveOrders.stripe_plans, message: 'unkown stripe plan' }

    validate(if: -> { subscribable.present? }) do
      subscribable.errors.add(:subscripter, 'is invalid') if self.errors.present?
    end

    # This is for the Choose Plan form's selected value.
    def stripe_plan_id
      @stripe_plan_id ||= subscribable.subscriptions.map { |subscription| subscription.stripe_plan_id }.first
    end

    def subscribe!(stripe_plan_id)
      assign_plan(stripe_plan_id)
      raise 'is invalid' unless valid?

      error = nil

      Effective::Subscription.transaction do
        begin
          # Create the customer
          if customer.stripe_customer_id.blank? && plan[:amount] > 0
            raise "unable to subscribe to #{plan[:name]}. Subscribing to a plan with amount > 0 requires a stripe customer token"
          end

          customer.save!

          # Create the subscription
          subscribable.subscriptions.build(customer: customer, subscribable: subscribable, stripe_plan_id: plan[:id]).save!

          return true
       rescue => e
         error = e.message
         raise ::ActiveRecord::Rollback
       end
      end

      raise "unable to subscribe to #{stripe_plan_id}: #{error}"
    end

    private

    def customer
      @customer ||= (subscribable.customer || subscribable.build_customer(buyer: subscribable))
    end

    def assign_plan(stripe_plan_id)
      @plan = EffectiveOrders.stripe_plans.find { |plan| plan[:id] == stripe_plan_id }
    end

  end
end
