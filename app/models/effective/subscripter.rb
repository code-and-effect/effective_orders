# Form object to select a subscription, and to handle all the logic

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :subscribable, :stripe_plan_id, :stripe_token
    delegate :email, to: :customer

    validates :subscribable, presence: true
    validates :plan, inclusion: { allow_blank: true, in: EffectiveOrders.stripe_plans, message: 'unknown plan' }

    validate(if: -> { stripe_plan_id && subscribable && plan.present? }) do
      if plan[:amount] > 0 && customer.stripe_active_card.blank?
        self.errors.add(:customer, 'customer payment token required for non-free plan')
      end
    end

    # Copy any errors upto subscribable
    validate(if: -> { errors.present? && subscribable }) { subscribable.errors.add(:subscripter, errors.full_messages.to_sentence) }

    def save!
      raise 'is invalid' unless valid?

      return true if current_plan == plan # No work to be done

      Effective::Subscription.transaction do
        begin
          stripe_token.present? ? customer.update_card!(stripe_token) : customer.save!

          # Create or Update the subscription (single subscription per customer implementation)
          if subscribable.subscription
            subscribable.subscription.change!(stripe_plan_id: plan[:id])
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

    def current_plan
      @current_plan ||= subscribable.subscription.try(:plan) || {}
    end

    def customer
      @customer ||= (subscribable.customer || subscribable.build_customer(buyer: subscribable))
    end

    def plan
      @plan ||= (EffectiveOrders.stripe_plans.find { |plan| plan[:id] == stripe_plan_id } if stripe_plan_id) || {}
    end

  end
end
