module Effective
  class Subscription < ActiveRecord::Base
    include EffectiveStripeHelper

    self.table_name = EffectiveOrders.subscriptions_table_name.to_s

    attr_accessor :has_coupon  # For the form

    belongs_to :customer, class_name: 'Effective::Customer'
    belongs_to :subscribable, polymorphic: true

    # Attributes
    # stripe_plan_id          :string  # This will be 'Weekly' or something like that
    # stripe_coupon_id        :string
    # stripe_subscription_id  :string
    #
    # title                   :string
    # price                   :integer, default: 0
    #
    # timestamps

    before_validation(if: -> { stripe_subscription_id.blank? && stripe_plan_id.present? && customer.present? }) { stripe_subscription }

    validates :customer, presence: true
    validates :subscribable, presence: true
    validates :stripe_plan_id, presence: true, inclusion: { in: EffectiveOrders.stripe_plans.keys }

    with_options(if: -> { stripe_plan_id.present? }) do
      validates :title, presence: true
      validates :price, numericality: { greater_than_or_equal_to: 0, only_integer: true }
      validates :customer_id, uniqueness: { scope: [:stripe_plan_id], message: 'is already subscribed to this plan' }
    end

    validate(if: -> { stripe_coupon_id.present? }) do
      self.errors.add(:stripe_coupon_id, 'is an invalid coupon') unless stripe_coupon
    end

    def tax_exempt
      true
    end

    def stripe_plan
      if stripe_plan_id.present?
        @stripe_plan ||= (Stripe::Plan.retrieve(stripe_plan_id) rescue nil)
      end
    end

    def stripe_coupon
      if stripe_coupon_id.present?
        @stripe_coupon ||= (Stripe::Coupon.retrieve(stripe_coupon_id) rescue nil)
      end
    end

    def stripe_subscription
      @stripe_subscription ||= if stripe_subscription_id.present?
        customer.stripe_customer.subscriptions.retrieve(stripe_subscription_id)
      else
        raise 'must have a customer and stripe_plan_id assigned to create a stripe subscription' unless customer.present? && stripe_plan_id.present?

        customer.stripe_customer.subscriptions.create(plan: stripe_plan_id, coupon: stripe_coupon_id.presence).tap do |stripe_subscription|
          self.stripe_subscription_id = stripe_subscription.id
          assign_price_and_title
        end
      end
    end

    def has_coupon
      stripe_coupon_id.present?
    end

    private

    def assign_price_and_title
      if (plan = EffectiveOrders.stripe_plans[stripe_plan_id])
        if stripe_coupon
          self.price = price_with_coupon(plan[:amount], stripe_coupon)
          self.title = plan[:name] + ' ' + stripe_plan_description(plan) + '<br>Coupon Code: ' + stripe_coupon_description(stripe_coupon)
        else
          self.price = plan[:amount]
          self.title = plan[:name] + ' ' + stripe_plan_description(plan)
        end
      end
    end

    def price_with_coupon(amount, coupon)
      if coupon.percent_off.present?
        (amount * (coupon.percent_off.to_i / 100.0)).round(0).to_i
      else
        [0, amount - coupon.amount_off].max
      end
    end

  end
end
