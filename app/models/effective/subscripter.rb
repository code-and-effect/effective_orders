# Form object to select a subscription, and to handle all the logic

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :subscribable, :stripe_plan_id, :stripe_token
    delegate :email, to: :customer

    validates :subscribable, presence: true
    validates :plan, if: -> { @stripe_plan_id }, inclusion: { in: EffectiveOrders.stripe_plans, message: 'unknown plan' }

    # validate(if: -> { @stripe_plan_id && plan[:amount].to_i > 0 }) do
    #   self.errors.add(:customer, 'customer payment required for non-free plan') unless customer.stripe_customer_id.present?
    # end

    # Copy any errors upto subscribable
    validate(if: -> { errors.present? }) { subscribable.errors.add(:subscripter, errors.full_messages.to_sentence) if subscribable }

    # This is for Choose Plan form's selected value.
    def stripe_plan_id
      @stripe_plan_id || current_plan[:id]
    end

    def save!
      raise 'is invalid' unless valid?

      return true if current_plan == plan # No work to be done

      Effective::Subscription.transaction do
        begin
          # Create the customer
          if customer.stripe_customer_id.blank? && plan[:amount] > 0
            raise "unable to subscribe to #{plan[:name]}. Subscribing to a non-free plan requires a customer token"
          end

          stripe_token.present? ? customer.update_card!(stripe_token) : customer.save!

          # Create or Update the subscription (single subscription per customer implementation)
          if (subscription = subscribable.subscriptions.first)
            subscription.change!(stripe_plan_id: plan[:id])
          else
            subscribable.subscriptions.build(customer: customer, subscribable: subscribable, stripe_plan_id: plan[:id]).save!
          end

          @current_plan = plan

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

    private

    def customer
      @customer ||= (subscribable.customer || subscribable.build_customer(buyer: subscribable))
    end

    def plan # Don't memoize
      if @stripe_plan_id
        EffectiveOrders.stripe_plans.find { |plan| plan[:id] == @stripe_plan_id }
      end || {}
    end

    def current_plan
      @current_plan ||= (
        id = subscribable.subscriptions.map { |subscription| subscription.stripe_plan_id }.first
        EffectiveOrders.stripe_plans.find { |plan| plan[:id] == id } || {}
      )
    end

  end
end
