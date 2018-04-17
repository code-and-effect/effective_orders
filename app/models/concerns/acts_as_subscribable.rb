module ActsAsSubscribable
  extend ActiveSupport::Concern

  mattr_accessor :descendants

  module ActiveRecord
    def acts_as_subscribable(*options)
      @acts_as_subscribable = options || []

      # instance = new()
      # raise 'must respond_to subscribed_plan' unless instance.respond_to?(:subscribed_plan)
      # raise 'must respond_to subscribed_until' unless instance.respond_to?(:subscribed_until)

      include ::ActsAsSubscribable
      (ActsAsSubscribable.descendants ||= []) << self
    end
  end

  included do
    has_one :subscription, as: :subscribable, class_name: 'Effective::Subscription'
    has_one :customer, through: :subscription, class_name: 'Effective::Customer'

    validates :subscripter, associated: true

    scope :subscribed, -> { where(id: joins(:subscription)) }  # All resources with a subscription
    scope :trialing, -> { where.not(id: joins(:subscription)) } # All resources without a subscription
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
    when (EffectiveOrders.stripe_plans['trial'] || {})[:id]
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
    trialing? && Time.zone.now > trial_expires_at
  end

  def trial_expires_at
    # The rake task send_trial_expiring_emails depends on this beginning_of_day
    ((created_at || Time.zone.now) + EffectiveOrders.subscriptions[:trial_period]).beginning_of_day
  end

  def buyer
    raise 'acts_as_subscribable object requires the buyer be defined to return the User buying this item.'
  end

end

