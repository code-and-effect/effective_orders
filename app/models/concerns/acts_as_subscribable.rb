module ActsAsSubscribable
  extend ActiveSupport::Concern

  mattr_accessor :descendants

  module Base
    def acts_as_subscribable(*options)
      @acts_as_subscribable = options || []

      include ::ActsAsSubscribable
      (ActsAsSubscribable.descendants ||= []) << self
    end
  end

  included do
    has_one :subscription, as: :subscribable, class_name: 'Effective::Subscription', inverse_of: :subscribable
    has_one :customer, through: :subscription, class_name: 'Effective::Customer'

    before_validation(if: -> { EffectiveOrders.trial? && trialing_until.blank? }) do
      self.trialing_until = (Time.zone.now + EffectiveOrders.trial.fetch(:length)).beginning_of_day
    end

    before_destroy(if: -> { subscribed? }) do
      raise :abort unless (subscripter.destroy! rescue false)
    end

    if EffectiveOrders.trial?
      validates :trialing_until, presence: true
    end

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
    @_effective_subscripter ||= begin
      Effective::Subscripter.new(subscribable: self, user: subscribable_buyer, quantity: subscription&.quantity, stripe_plan_id: subscription&.stripe_plan_id)
    end
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

  # If we do use stripe
  def subscription_trialing?
    subscribed? && subscription_status == EffectiveOrders::TRIALING
  end

  # If we don't use stripe
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

  def subscribable_quantity_used
    raise 'acts_as_subscribable object requires the subscribable_quantity_used method be defined to determine how many are in use.'
  end

end
