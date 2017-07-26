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

  def subcription(name)
    plan = EffectiveOrders.stripe_plans[name.to_s] || raise("unknown stripe plan: #{name}")
    subscriptions.find { |subscription| subscription.stripe_plan_id == plan[:id] }
  end

  def subscribed_to?(name)
    subcription(name).present?
  end

end

