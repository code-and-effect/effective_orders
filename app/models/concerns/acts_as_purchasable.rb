module ActsAsPurchasable
  extend ActiveSupport::Concern

  mattr_accessor :descendants

  module ActiveRecord
    def acts_as_purchasable(*options)
      @acts_as_purchasable = options || []
      include ::ActsAsPurchasable
      (ActsAsPurchasable.descendants ||= []) << self
    end
  end

  included do
    has_many :cart_items, as: :purchasable, dependent: :delete_all, class_name: 'Effective::CartItem'

    has_many :order_items, as: :purchasable, class_name: 'Effective::OrderItem'
    has_many :orders, -> { order(:id) }, through: :order_items, class_name: 'Effective::Order'

    has_many :purchased_orders, -> { where(purchase_state: EffectiveOrders::PURCHASED).order(:purchased_at) },
      through: :order_items, class_name: 'Effective::Order', source: :order

    validates_with Effective::SoldOutValidator, on: :create

    # Database max integer value is 2147483647.  So let's round that down and use a max/min of $20 million (2000000000)
    validates :price, presence: true, numericality: { less_than_or_equal_to: 2000000000, message: 'maximum price is $20,000,000' }

    validates :tax_exempt, inclusion: { in: [true, false] }

    # These are breaking on the check for quanitty_enabled?.  More research is due
    validates :quantity_purchased, numericality: { allow_nil: true }, if: proc { |purchasable| (purchasable.quantity_enabled? rescue false) }
    validates :quantity_max, numericality: { allow_nil: true }, if: proc { |purchasable| (purchasable.quantity_enabled? rescue false) }

    scope :purchased, -> { joins(order_items: :order).where(orders: {purchase_state: EffectiveOrders::PURCHASED}).distinct }
    scope :purchased_by, lambda { |user| joins(order_items: :order).where(orders: {user_id: user.try(:id), purchase_state: EffectiveOrders::PURCHASED}).distinct }
    scope :sold, -> { purchased() }
    scope :sold_by, lambda { |user| joins(order_items: :order).where(order_items: {seller_id: user.try(:id)}).where(orders: {purchase_state: EffectiveOrders::PURCHASED}).distinct }

    scope :not_purchased, -> { where('id NOT IN (?)', purchased.pluck(:id).presence || [0]) }
    scope :not_purchased_by, lambda { |user| where('id NOT IN (?)', purchased_by(user).pluck(:id).presence || [0]) }
  end

  module ClassMethods
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

  def price
    self[:price] || 0
  end

  # If I have a column type of Integer, and I'm passed a non-Integer, convert it here
  def price=(value)
    if value.kind_of?(Integer)
      super
    else
      raise 'expected price to be an Integer representing the number of cents.'
    end
  end

  def title
    self[:title] || to_s
  end

  def tax_exempt
    self[:tax_exempt] || false
  end

  def purchased_order
    @purchased_order ||= purchased_orders.first
  end

  def purchased?
    @is_purchased ||= purchased_order.present?
  end

  def purchased_by?(user)
    purchased_orders.any? { |order| order.user_id == user.id }
  end

  def purchased_at
    purchased_order.try(:purchased_at)
  end

  def quantity_enabled?
    self.respond_to?(:quantity_enabled) ? quantity_enabled == true : false
  end

  def quantity_remaining
    (quantity_max - quantity_purchased) rescue 0
  end

  def sold_out?
    quantity_enabled? ? (quantity_remaining == 0) : false
  end

  # Override me if this is a digital purchase.
  def purchased_download_url
    false
  end

end

