# Acts as purchasable
# Add to your model:
# t.integer :purchased_order_id
# t.integer :price
# t.boolean :tax_exempt, default: false
# t.string :qb_item_name
# or
# add_column :resources, :purchased_order_id, :integer
# add_column :resources, :price, :integer
# add_column :resources, :tax_exempt, :boolean, default: false
# add_column :resources, :qb_item_name, :string
#
# You can also optionally add :purchased_at :datetime, and purchased_by_id and purchased_by_type

module ActsAsPurchasable
  extend ActiveSupport::Concern

  module Base
    def acts_as_purchasable(*options)
      @acts_as_purchasable = options || []
      include ::ActsAsPurchasable
    end
  end

  included do
    belongs_to :purchased_order, class_name: 'Effective::Order', optional: true # Set when purchased

    has_many :cart_items, as: :purchasable, dependent: :delete_all, class_name: 'Effective::CartItem'

    has_many :order_items, as: :purchasable, class_name: 'Effective::OrderItem'
    has_many :orders, -> { order(:id) }, through: :order_items, class_name: 'Effective::Order'

    has_many :purchased_orders, -> { where(status: :purchased).order(:purchased_at) },
      through: :order_items, class_name: 'Effective::Order', source: :order

    has_many :deferred_orders, -> { where(status: :deferred).order(:created_at) },
      through: :order_items, class_name: 'Effective::Order', source: :order

    # Database max integer value is 2147483647.  So let's round that down and use a max/min of $20 million (2000000000)
    validates :price, presence: true
    validates :price, numericality: { less_than_or_equal_to: 2000000000, message: 'maximum price is $20,000,000' }
    validates :price, numericality: { greater_than_or_equal_to: -2000000000, message: 'minimum price is -$20,000,000' }

    validates :tax_exempt, inclusion: { in: [true, false] }

    with_options(if: -> { quantity_enabled? }) do
      validates :quantity_purchased, numericality: { allow_nil: true }
      validates :quantity_max, numericality: { allow_nil: true }
      validates_with Effective::SoldOutValidator, on: :create
    end

    with_options(if: -> { EffectiveOrders.require_item_names? }) do
      validates :qb_item_name, presence: true
    end

    scope :purchased, -> { 
      if respond_to?(:unarchived)
        unarchived.where.not(purchased_order_id: nil) 
      else
        where.not(purchased_order_id: nil) 
      end
    }

    scope :not_purchased, -> { 
      if respond_to?(:unarchived)
        unarchived.where(purchased_order_id: nil) 
      else
        where(purchased_order_id: nil) 
      end
    }

    scope :not_purchased_or_deferred, -> { 
      where(purchased_order_id: nil).where.not(id: purchased_or_deferred)
    }

    scope :purchased_or_deferred, -> { 
      if respond_to?(:unarchived)
        unarchived.joins(order_items: :order).where(orders: { status: [:purchased, :deferred] }) 
      else
        joins(order_items: :order).where(orders: { status: [:purchased, :deferred] }) 
      end
    }

    scope :deferred, -> { 
      if respond_to?(:unarchived)
        unarchived.joins(order_items: :order).where(orders: { status: :deferred })
      else
        joins(order_items: :order).where(orders: { status: :deferred })
      end
    }

    scope :purchased_by, -> (user) { 
      if respond_to?(:unarchived)
        unarchived.joins(order_items: :order).where(orders: { purchased_by: user, status: :purchased }).distinct 
      else
        joins(order_items: :order).where(orders: { purchased_by: user, status: :purchased }).distinct 
      end
    }

    scope :not_purchased_by, -> (user) { where.not(id: purchased_by(user)) }
  end

  module ClassMethods
    def acts_as_purchasable?; true; end

    def before_defer(&block)
      send :define_method, :before_defer do |order, order_item| self.instance_exec(order, order_item, &block) end
    end

    def after_defer(&block)
      send :define_method, :after_defer do |order, order_item| self.instance_exec(order, order_item, &block) end
    end

    def before_purchase(&block)
      send :define_method, :before_purchase do |order, order_item| self.instance_exec(order, order_item, &block) end
    end

    def after_purchase(&block)
      send :define_method, :after_purchase do |order, order_item| self.instance_exec(order, order_item, &block) end
    end

    def before_decline(&block)
      send :define_method, :before_decline do |order, order_item| self.instance_exec(order, order_item, &block) end
    end

    def after_decline(&block)
      send :define_method, :after_decline do |order, order_item| self.instance_exec(order, order_item, &block) end
    end
  end

  # Regular instance methods

  # If I have a column type of Integer, and I'm passed a non-Integer, convert it here
  def price=(value)
    if value.kind_of?(Integer)
      super
    elsif value.kind_of?(String) && !value.include?('.') # Looks like an integer
      super
    elsif value.blank?
      super
    else
      raise "expected price to be an Integer representing the number of cents. Got: #{value}"
    end
  end

  def purchasable_name
    to_s
  end

  def tax_exempt
    self[:tax_exempt] || false
  end

  def purchased_or_deferred?
    purchased_order_id.present? || orders.any? { |order| order.purchased? || order.deferred? }
  end

  def purchased_or_deferred_at
    order = orders.find { |order| order.purchased? } || orders.find { |order| order.deferred? } 
    order&.purchased_at || order&.deferred_at
  end

  def purchased?
    purchased_order_id.present?
  end

  def deferred?
    deferred_orders.any? { |order| order.deferred? }
  end

  def purchased_at
    self[:purchased_at] || purchased_order.try(:purchased_at)
  end

  def deferred_at
    self[:deferred_at] || orders.find { |order| order.deferred? }.try(:deferred_at)
  end

  def purchased_by?(user)
    purchased_orders.any? { |order| order.purchased_by_id == user.id }
  end

  def purchased_before?(date)
    return false unless purchased?
    return false unless purchased_at.present?

    purchased_at < date
  end

  def purchased_after?(date)
    return false unless purchased?
    return false unless purchased_at.present?

    purchased_at >= date
  end

  def purchased_download_url # Override me if this is a digital purchase.
    false
  end

  def quantity_enabled?
    false
  end

  def quantity_remaining
    quantity_max - quantity_purchased if quantity_enabled?
  end

  def sold_out?
    quantity_enabled? ? (quantity_remaining <= 0) : false
  end

end
