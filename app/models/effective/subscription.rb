# This is not a Stripe Subscription object.  This is a subscription's item.

module Effective
  class Subscription < ActiveRecord::Base
    self.table_name = EffectiveOrders.subscriptions_table_name.to_s

    belongs_to :customer, class_name: 'Effective::Customer', counter_cache: true
    belongs_to :subscribable, polymorphic: true

    # Attributes
    # stripe_plan_id          :string  # This will be 'bronze' or something like that
    #
    # name                    :string
    # price                   :integer, default: 0
    #
    # timestamps

    before_validation(if: -> { stripe_plan_id_changed? && plan }) do
      self.name = "#{plan[:name]} #{plan[:description]}"
      self.price = plan[:amount]
    end

    validates :customer, presence: true
    validates :subscribable, presence: true
    validates :stripe_plan_id, presence: true, inclusion: { in: EffectiveOrders.stripe_plans.keys }

    validates :name, presence: true
    validates :price, numericality: { greater_than_or_equal_to: 0, only_integer: true }

    validates :customer_id, if: -> { subscribable },
      uniqueness: { scope: [:subscribable_id, :subscribable_type], message: "can't subscribe to same subscribable twice" }

    def to_s
      name.presence || 'New Subscription'
    end

    def plan
      EffectiveOrders.stripe_plans[stripe_plan_id]
    end

    # def stripe_plan
    #   if stripe_plan_id.present?
    #     @stripe_plan ||= (Stripe::Plan.retrieve(stripe_plan_id) rescue nil)
    #   end
    # end

    # def stripe_coupon
    #   if stripe_coupon_id.present?
    #     @stripe_coupon ||= (Stripe::Coupon.retrieve(stripe_coupon_id) rescue nil)
    #   end
    # end

    # def stripe_subscription
    #   @stripe_subscription ||= if stripe_subscription_id.present?
    #     customer.stripe_customer.subscriptions.retrieve(stripe_subscription_id)
    #   else
    #     raise 'must have a customer and stripe_plan_id assigned to create a stripe subscription' unless customer.present? && stripe_plan_id.present?

    #     Rails.logger.info "STRIPE SUBSCRIPTION CREATE: #{customer} #{stripe_plan_id} and #{stripe_coupon_id.presence || 'no coupon'}"

    #     customer.stripe_customer.subscriptions.create(plan: stripe_plan_id, coupon: stripe_coupon_id.presence).tap do |stripe_subscription|
    #       self.stripe_subscription_id = stripe_subscription.id
    #       assign_price_and_title
    #     end
    #   end
    # end

    # def invoices
    #   @invoices ||= (
    #     customer.stripe_customer.invoices.all.select do |invoice|
    #       invoice.lines.any? { |line| line.id == stripe_subscription_id }
    #     end
    #   )
    # end

    # def change!(stripe_plan_id:)
    #   raise 'subscription must be persisted' unless persisted?
    #   raise 'stripe subscription must exist' unless stripe_subscription.present?

    #   # Change myself
    #   self.stripe_plan_id = stripe_plan_id
    #   assign_price_and_title
    #   save!

    #   # Change with Stripe
    #   Rails.logger.info "STRIPE SUBSCRIPTION CHANGE: #{customer} #{stripe_plan_id} and #{stripe_coupon_id.presence || 'no coupon'}"
    #   stripe_subscription.plan = stripe_plan_id
    #   stripe_subscription.proration_date = Time.zone.now.to_i
    #   stripe_subscription.save || raise('unable to save stripe subscription')
    # end

    # private

    # def assign_price_and_title
    #   if plan.present?
    #     if stripe_coupon
    #       self.price = price_with_coupon(plan[:amount], stripe_coupon)
    #       self.title = "#{plan[:name]} #{plan[:description]} with coupon #{stripe_coupon.id}"
    #     else
    #       self.price = plan[:amount]
    #       self.title = "#{plan[:name]} #{plan[:description]}"
    #     end
    #   end
    # end

    # def price_with_coupon(amount, coupon)
    #   if coupon.percent_off.present?
    #     (amount * (coupon.percent_off.to_i / 100.0)).round(0).to_i
    #   else
    #     [0, amount - coupon.amount_off].max
    #   end
    # end

  end
end
