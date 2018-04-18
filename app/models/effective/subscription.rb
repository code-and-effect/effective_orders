# This links the acts_as_subscribable_buyer (customer) to the acts_as_subscribable (subscribable)

module Effective
  class Subscription < ActiveRecord::Base
    self.table_name = EffectiveOrders.subscriptions_table_name.to_s

    belongs_to :customer, class_name: 'Effective::Customer', counter_cache: true
    belongs_to :subscribable, polymorphic: true

    # Attributes
    # stripe_plan_id          :string
    # name                    :string
    #
    # timestamps

    before_validation(if: -> { plan && (stripe_plan_id_changed? || new_record?) }) do
      self.name = "#{plan[:name]} #{plan[:description]}"
    end

    validates :customer, presence: true
    validates :subscribable, presence: true

    validates :stripe_plan_id, presence: true, inclusion: { in: EffectiveOrders.stripe_plans.except('trial').keys }
    validates :name, presence: true

    def to_s
      name || 'New Subscription'
    end

    def plan
      EffectiveOrders.stripe_plans[stripe_plan_id]
    end

    def <=>(other)
      name.to_s <=> other&.name.to_s
    end

  end
end
