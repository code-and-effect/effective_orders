module Effective
  class Subscription < ActiveRecord::Base
    self.table_name = EffectiveOrders.subscriptions_table_name.to_s

    attr_accessor :stripe_subscription

    belongs_to :customer, class_name: 'Effective::Customer', counter_cache: true
    belongs_to :subscribable, polymorphic: true

    # Attributes
    # stripe_plan_id            :string
    # stripe_subscription_id    :string
    # name                      :string
    # description               :string
    # interval                  :string
    # quantity                  :integer
    #
    # status                    :string
    #
    # timestamps

    before_validation(if: -> { plan && (stripe_plan_id_changed? || new_record?) }) do
      self.name = plan[:name]
      self.description = plan[:description]
    end

    after_save do
      subscribable.subscription_name = name if subscribable.respond_to?(:subscription_name=)
      subscribable.subscription_description = description if subscribable.respond_to?(:subscription_description=)
      subscribable.subscription_interval = interval if subscribable.respond_to?(:subscription_interval=)
      subscribable.subscription_quantity = quantity if subscribable.respond_to?(:subscription_quantity=)
      subscribable.subscription_status = status if subscribable.respond_to?(:subscription_status=)
      subscribable.save!(validate: false)
    end

    after_destroy do
      subscribable.subscription_name = nil if subscribable.respond_to?(:subscription_name=)
      subscribable.subscription_description = nil if subscribable.respond_to?(:subscription_description=)
      subscribable.subscription_interval = nil if subscribable.respond_to?(:subscription_interval=)
      subscribable.subscription_quantity = nil if subscribable.respond_to?(:subscription_quantity=)
      subscribable.subscription_status = nil if subscribable.respond_to?(:subscription_status=)
      subscribable.save!(validate: false)
    end

    validates :customer, presence: true
    validates :subscribable, presence: true

    validates :stripe_plan_id, presence: true
    validates :stripe_plan_id, inclusion: { in: EffectiveOrders.stripe_plans.map { |plan| plan[:id] } }

    validates :stripe_subscription_id, presence: true

    validates :name, presence: true
    validates :interval, presence: true
    validates :quantity, presence: true, numericality: { greater_than: 0 }

    validates :status, inclusion: { in: EffectiveOrders::STATUSES.keys }

    def to_s
      name || 'New Subscription'
    end

    def plan
      EffectiveOrders.stripe_plans.find { |plan| plan[:id] == stripe_plan_id }
    end

    def stripe_subscription
      @stripe_subscription ||= if stripe_subscription_id.present?
        Rails.logger.info "[STRIPE] get subscription: #{stripe_subscription_id}"
        ::Stripe::Subscription.retrieve(stripe_subscription_id)
      end
    end

    def <=>(other)
      name.to_s <=> other&.name.to_s
    end

    def active?
      status == 'active'
    end

    def past_due?
      status == 'past_due'
    end

    def canceled?
      status == 'canceled'
    end

  end
end
