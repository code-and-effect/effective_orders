module ActsAsSubscribable
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_subscribable(*options)
      include ::ActsAsSubscribable
    end
  end

  included do
    has_one :subscription, as: :subscribable, class_name: 'Effective::Subscription'
    has_one :customer, through: :subscription, class_name: 'Effective::Customer'

    validates :subscripter, associated: true
  end

  module ClassMethods
  end

  def subscripter
    @_effective_subscripter ||= Effective::Subscripter.new(subscribable: self, user: buyer)
  end

  def subscripter=(atts)
    subscripter.assign_attributes(atts)
  end

  def subscribed?(stripe_plan_id = nil)
    case stripe_plan_id
    when nil
      subscription.present?  # Subscribed to any subscription?
    when EffectiveOrders.stripe_blank_plan[:id]
      subscription.blank? || subscription.new_record? || subscription.stripe_plan_id == stripe_plan_id
    else
      subscription && subscription.persisted? && subscription.errors.blank? && subscription.stripe_plan_id == stripe_plan_id
    end
  end

  def subscription_active?
    (trialing? && !trial_expired?) || (subscribed? && subscription.active?)
  end

  def trialing?
    !subscribed?
  end

  def trial_expired?
    (Time.zone.now - created_at) > EffectiveOrders.subscription[:trial_period]
  end

  def buyer
    raise 'acts_as_subscribable object requires the buyer be defined to return the User buying this item.'
  end

end

