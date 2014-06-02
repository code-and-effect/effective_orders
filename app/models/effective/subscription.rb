module Effective
  class Subscription < ActiveRecord::Base
    include EffectiveStripeHelper

    self.table_name = EffectiveOrders.subscriptions_table_name.to_s

    acts_as_purchasable

    belongs_to :customer

    structure do
      stripe_plan_id          :string, :validates => [:presence]  # This will be 'Weekly' or something like that
      stripe_subscription_id  :string#, :validates => [:presence]
      stripe_coupon_id        :string

      title                   :string, :validates => [:presence]
      price                   :decimal, :precision => 8, :scale => 2, :default => 0.00, :validates => [:numericality => {:greater_than => 0.0}]

      timestamps
    end

    validates_presence_of :customer
    validates_uniqueness_of :customer_id, :scope => [:stripe_plan_id] # Can only be on each plan once.

    before_validation do
      if stripe_coupon_id.present? && stripe_coupon.blank?
        self.errors.add(:stripe_coupon_id, "is an invalid Coupon")
      end

      if stripe_plan_id.present?
        if stripe_plan.blank?
          self.errors.add(:stripe_plan_id, "is an invalid Plan")
        else
          self.title = stripe_plan_description(stripe_plan)
          self.price = (stripe_plan.amount / 100.0)
        end
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

  end
end
