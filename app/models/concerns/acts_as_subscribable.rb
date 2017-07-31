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
    @_effective_subscripter ||= Effective::Subscripter.new(subscribable: self)
  end

  def subscripter=(atts)
    subscripter.assign_attributes(atts)
  end

  def subscription(stripe_plan_id = nil)
    @_effective_subscription ||= (
      if stripe_plan_id.nil?
        subscriptions.to_a.first
      else
        subscriptions.to_a.find { |sub| sub.stripe_plan_id == stripe_plan_id }
      end
    )
  end

  def subscribed?(stripe_plan_id)
    subscriptions.to_a.find { |sub| sub.stripe_plan_id == stripe_plan_id && sub.persisted? }.present?
  end

end

