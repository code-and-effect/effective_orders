# Mostly for the callbacks

module ActsAsPurchasableParent
  extend ActiveSupport::Concern

  module Base
    def acts_as_purchasable_parent(*options)
      @acts_as_purchasable_parent = options || []
      include ::ActsAsPurchasableParent
    end
  end

  module ClassMethods
    def acts_as_purchasable_parent?; true; end

    def before_defer(&block)
      send :define_method, :before_defer do |order| self.instance_exec(order, &block) end
    end

    def after_defer(&block)
      send :define_method, :after_defer do |order| self.instance_exec(order, &block) end
    end

    def before_purchase(&block)
      send :define_method, :before_purchase do |order| self.instance_exec(order, &block) end
    end

    def after_purchase(&block)
      send :define_method, :after_purchase do |order| self.instance_exec(order, &block) end
    end

    def before_decline(&block)
      send :define_method, :before_decline do |order| self.instance_exec(order, &block) end
    end

    def after_decline(&block)
      send :define_method, :after_decline do |order| self.instance_exec(order, &block) end
    end
  end

  included do
    has_many :orders, -> { order(:id) }, as: :parent, class_name: 'Effective::Order'

    accepts_nested_attributes_for :orders

    before_destroy do
      orders.each do |order|
        raise('unable to destroy a purchasable_parent with purchased orders') if order.purchased?
        order.voided? ? order.save! : order.void!
      end

      true
    end

  end

end
