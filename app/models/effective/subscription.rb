# This is not a Stripe Subscription object.  This is a subscription's item.

module Effective
  class Subscription < ActiveRecord::Base
    self.table_name = EffectiveOrders.subscriptions_table_name.to_s

    belongs_to :customer, class_name: 'Effective::Customer', counter_cache: true, autosave: true
    belongs_to :subscribable, polymorphic: true

    # Attributes
    # stripe_plan_id          :string  # This will be 'bronze' or something like that
    # current_period_end      :datetime
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

  end
end
