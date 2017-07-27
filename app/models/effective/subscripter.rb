# Form object to select a subscription, and to handle all the logic

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :subscribable, :stripe_plan_id

    validates :subscribable, presence: true

    validate(if: -> { subscribable.present? }) do
      subscribable.errors.add(:subscripter, 'is invalid') if self.errors.present?
    end

    validate do
      self.errors.add(:stripe_plan_id, 'oh man')
    end

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

    def assign_plan(name)
      self.plan = EffectiveOrders.stripe_plans[name.to_s]
    end

  end
end
