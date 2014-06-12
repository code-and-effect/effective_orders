module Effective
  class Subscription < ActiveRecord::Base
    include EffectiveStripeHelper

    self.table_name = EffectiveOrders.subscriptions_table_name.to_s

    acts_as_purchasable

    belongs_to :customer

    structure do
      stripe_plan_id          :string, :validates => [:presence]  # This will be 'Weekly' or something like that
      stripe_subscription_id  :string
      stripe_coupon_id        :string

      title                   :string, :validates => [:presence]
      price                   :decimal, :precision => 8, :scale => 2, :default => 0.00, :validates => [:numericality => {:greater_than => 0.0}]

      timestamps
    end

    delegate :user, :user_id, :to => :customer

    validates_presence_of :customer
    validates_uniqueness_of :customer_id, :scope => [:stripe_plan_id] # Can only be on each plan once.

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
          self.price = (price_with_coupon(stripe_plan.amount, stripe_coupon) / 100.0)
          self.title = stripe_plan_description(stripe_plan) + '<br>Coupon Code: ' + stripe_coupon_description(stripe_coupon)
        else
          self.title = stripe_plan_description(stripe_plan)
          self.price = (stripe_plan.amount / 100.0)
        end
      end
    end

    def price_with_coupon(amount, coupon)
      if coupon.percent_off.present?
        (amount * (coupon.percent_off.to_i / 100.0)).floor
      else
        [0, amount - coupon.amount_off].max
      end
    end

  end
end
