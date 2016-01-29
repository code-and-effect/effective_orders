module Effective
  class Subscription < ActiveRecord::Base
    include EffectiveStripeHelper

    self.table_name = EffectiveOrders.subscriptions_table_name.to_s

    acts_as_purchasable

    belongs_to :customer

    delegate :user, :user_id, :to => :customer

    validates :stripe_plan_id, presence: true
    validates :title, presence: true
    validates :price, numericality: { greater_than: 0 }

    validates :customer, presence: true
    validates :customer_id, uniqueness: { scope: [:stripe_plan_id] }  # Can only be on each plan once.

    before_validation do
      self.errors.add(:stripe_plan_id, "is an invalid Plan") if stripe_plan_id.present? && stripe_plan.blank?
      self.errors.add(:stripe_coupon_id, "is an invalid Coupon") if stripe_coupon_id.present? && stripe_coupon.blank?
    end

    def tax_exempt
      true
    end

    def stripe_plan_id=(plan_id)
      unless self[:stripe_plan_id] == plan_id
        self[:stripe_plan_id] = plan_id
        @stripe_plan = nil   # Remove any memoization

        assign_price_and_title()
      end
    end

    def stripe_coupon_id=(coupon_id)
      unless self[:stripe_coupon_id] == coupon_id
        self[:stripe_coupon_id] = coupon_id
        @stripe_coupon = nil   # Remove any memoization

        assign_price_and_title()
      end
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
      if stripe_subscription_id.present?
        @stripe_subscription ||= (customer.stripe_customer.subscriptions.retrieve(stripe_subscription_id) rescue nil)
      end
    end

    private

    def assign_price_and_title
      if stripe_plan
        if stripe_coupon
          self.price = price_with_coupon(stripe_plan.amount, stripe_coupon)
          self.title = stripe_plan_description(stripe_plan) + '<br>Coupon Code: ' + stripe_coupon_description(stripe_coupon)
        else
          self.title = stripe_plan_description(stripe_plan)
          self.price = stripe_plan.amount
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
