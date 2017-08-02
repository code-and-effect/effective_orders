module ActsAsSubscribable
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_subscribable(*options)
      include ::ActsAsSubscribable
    end
  end

  included do
    has_one :customer, through: :subscription, class_name: 'Effective::Customer'
    has_one :subscription, as: :subscribable, class_name: 'Effective::Subscription'

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

  def buyer
    raise 'acts_as_subscribable object requires the buyer be defined to return the User buying this item.'
  end

end

