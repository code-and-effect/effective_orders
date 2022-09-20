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

    has_many :purchased_orders, -> { where(state: EffectiveOrders::PURCHASED).order(:purchased_at) },
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

    scope :purchased, -> { where.not(purchased_order_id: nil) }
    scope :not_purchased, -> { where(purchased_order_id: nil) }

    # scope :purchased, -> { joins(order_items: :order).where(orders: {state: EffectiveOrders::PURCHASED}).distinct }
    # scope :not_purchased, -> { where('id NOT IN (?)', purchased.pluck(:id).presence || [0]) }
    scope :purchased_by, lambda { |user| joins(order_items: :order).where(orders: { user_id: user.try(:id), state: EffectiveOrders::PURCHASED }).distinct }
    scope :not_purchased_by, lambda { |user| where('id NOT IN (?)', purchased_by(user).pluck(:id).presence || [0]) }
  end

  module ClassMethods
    def acts_as_purchasable?; true; end

    def before_purchase(&block)
      send :define_method, :before_purchase do |order, order_item| self.instance_exec(order, order_item, &block) end
    end

    def after_purchase(&block)
      send :define_method, :after_purchase do |order, order_item| self.instance_exec(order, order_item, &block) end
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
      raise 'expected price to be an Integer representing the number of cents.'
    end
  end

  def purchasable_name
    to_s
  end

  def tax_exempt
    self[:tax_exempt] || false
  end

  def purchased?
    purchased_order_id.present?
  end

  def purchased_at
    purchased_order.try(:purchased_at)
  end

  def purchased_by?(user)
    purchased_orders.any? { |order| order.user_id == user.id }
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
