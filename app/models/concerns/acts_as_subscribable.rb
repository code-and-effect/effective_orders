module ActsAsSubscribable
  extend ActiveSupport::Concern

  mattr_accessor :descendants

  module ActiveRecord
    def acts_as_subscribable(*options)
      @acts_as_subscribable = options || []

      instance = new()
      raise 'must respond to trialing_until' unless instance.respond_to?(:trialing_until)
      raise 'must respond to subscription_status' unless instance.respond_to?(:subscription_status)

      include ::ActsAsSubscribable
      (ActsAsSubscribable.descendants ||= []) << self
    end
  end

  included do
    has_one :subscription, as: :subscribable, class_name: 'Effective::Subscription'
    has_one :customer, through: :subscription, class_name: 'Effective::Customer'

    before_validation(if: -> { trialing_until.blank? && EffectiveOrders.trial? }) do
      self.trialing_until = (Time.zone.now + EffectiveOrders.trial.fetch(:length)).beginning_of_day
    end

    before_destroy(if: -> { subscribed? }) do
      raise :abort unless (subscripter.destroy! rescue false)
    end

    validates :trialing_until, presence: true, if: -> { EffectiveOrders.trial? }
    validates :subscription_status, inclusion: { allow_nil: true, in: EffectiveOrders::STATUSES.keys }

    scope :trialing, -> { where(subscription_status: nil).where('trialing_until > ?', Time.zone.now) }
    scope :trial_past_due, -> { where(subscription_status: nil).where('trialing_until < ?', Time.zone.now) }
    scope :not_trialing, -> { where.not(subscription_status: nil) }

    scope :subscribed, -> { where(subscription_status: EffectiveOrders::ACTIVE) }
    scope :subscription_past_due, -> { where(subscription_status: EffectiveOrders::PAST_DUE) }
    scope :not_subscribed, -> { where(subscription_status: nil) }
  end

  module ClassMethods
  end

  def subscripter
    @_effective_subscripter ||= Effective::Subscripter.new(subscribable: self, user: subscribable_buyer)
  end

  def subscribed?(stripe_plan_id = nil)
    return false if subscription_status.blank?
    stripe_plan_id ? (subscription&.stripe_plan_id == stripe_plan_id) : true
  end

  def subscription_active?
    subscribed? && subscription_status == EffectiveOrders::ACTIVE
  end

  def subscription_past_due?
    subscribed? && subscription_status == EffectiveOrders::PAST_DUE
  end

  def trialing?
    subscription_status.blank?
  end

  def trial_active?
    trialing? && trialing_until > Time.zone.now
  end

  def trial_past_due?
    trialing? && trialing_until < Time.zone.now
  end

  def subscribable_buyer
    raise 'acts_as_subscribable object requires the subscribable_buyer method be defined to return the User buying this item.'
  end

end

