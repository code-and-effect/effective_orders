module ActsAsSubscribable
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_subscribable(*options)
      include ::ActsAsSubscribable
    end
  end

  included do
    has_one :subscription, as: :subscribable, class_name: 'Effective::Subscription', autosave: true
    has_one :customer, through: :subscription, class_name: 'Effective::Customer'
  end

  module ClassMethods
  end

  def subscripter
    @_effective_subscripter ||= Effective::Subscripter.new(subscribable: self, user: buyer)
  end

  def subscripter=(atts)
    subscripter.assign_attributes(atts)
  end

  def subscribed?(stripe_plan_id)
    if [nil, EffectiveOrders.stripe_blank_plan[:id]].include?(stripe_plan_id)
      subscription.blank? || subscription.new_record? || subscription.stripe_plan_id == stripe_plan_id
    else
      subscription && subscription.persisted? && subscription.errors.blank? && subscription.stripe_plan_id == stripe_plan_id
    end
  end

  def buyer
    raise 'acts_as_subscribable object requires the buyer be defined to return the User buying this item.'
  end

end

