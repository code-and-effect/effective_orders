module ActsAsSubscribable
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_subscribable(*options)
      include ::ActsAsSubscribable
    end
  end

  included do
    has_one :customer, as: :buyer, class_name: 'Effective::Customer'
    has_many :subscriptions, as: :subscribable, class_name: 'Effective::Subscription'

    validates :subscripter, associated: true
  end

  module ClassMethods
  end

  def subscripter
    @subscripter ||= Effective::Subscripter.new(subscribable: self)
  end

  def subscripter=(atts)
    subscripter.assign_attributes(atts)
  end

  def subcription(stripe_plan_id)
    plan = EffectiveOrders.stripe_plans.find { |plan| plan[:id] == stripe_plan_id } || raise("unknown stripe plan: #{stripe_plan_id}")
    subscriptions.find { |subscription| subscription.stripe_plan_id == plan[:id] }
  end

  def subscribed?(stripe_plan_id)
    subcription(stripe_plan_id).present?
  end

end

