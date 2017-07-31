# Form object to select a subscription, and to handle all the logic

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :subscribable, :stripe_plan_id

    validates :subscribable, presence: true
    validates :plan, if: -> { @stripe_plan_id }, inclusion: { in: EffectiveOrders.stripe_plans, message: 'unknown plan' }

    validate(if: -> { subscribable.present? && errors.present? }) { subscribable.errors.add(:subscripter, 'is invalid') }

    # This is for Choose Plan form's selected value.
    def stripe_plan_id
      @stripe_plan_id || current_plan[:id]
    end

    def save!
      raise 'is invalid' unless valid?
      return true if current_plan == plan # No work to be done

      error = nil

      Effective::Subscription.transaction do
        begin
          # Create the customer
          if customer.stripe_customer_id.blank? && plan[:amount] > 0
            raise "unable to subscribe to #{plan[:name]}. Subscribing to a plan with amount > 0 requires a customer token"
          end

          customer.save!

          # Create the subscription
          subscribable.subscriptions.build(customer: customer, subscribable: subscribable, stripe_plan_id: plan[:id]).save!
          @current_plan = plan

          return true
        rescue => e
          error = e.message
          raise ::ActiveRecord::Rollback
        end
      end

      raise "unable to subscribe to #{plan[:id]}: #{error}"
    end

    def subscribe!(stripe_plan_id)
      self.stripe_plan_id = stripe_plan_id
      save!
    end

    private

    def customer
      @customer ||= (subscribable.customer || subscribable.build_customer(buyer: subscribable))
    end

    def plan # Don't memoize
      EffectiveOrders.stripe_plans.find { |plan| plan[:id] == stripe_plan_id } || {}
    end

    def current_plan
      @current_plan ||= (
        id = (subscribable.try(:subscriptions) || []).map { |subscription| subscription.stripe_plan_id }.first
        EffectiveOrders.stripe_plans.find { |plan| plan[:id] == id } || {}
      )
    end

  end
end
