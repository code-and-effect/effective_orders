module ActsAsPurchasable
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_purchasable(*options)
      @acts_as_purchasable = options || []
      include ::ActsAsPurchasable
    end
  end

  included do
    has_many :orders, :through => :order_items, :class_name => 'Effective::Order'
    has_many :order_items, :as => :purchasable, :class_name => 'Effective::OrderItem'
    has_many :cart_items, :as => :purchasable, :dependent => :delete_all, :class_name => 'Effective::CartItem'

    validates_with Effective::SoldOutValidator, :on => :create

    validates :price, :presence => true, :numericality => true
    validates :tax_exempt, :inclusion => {:in => [true, false]}

    # These are breaking on the check for quanitty_enabled?.  More research is due
    validates :quantity_purchased, :numericality => {:allow_nil => true}, :if => proc { |purchasable| (purchasable.quantity_enabled? rescue false) }
    validates :quantity_max, :numericality => {:allow_nil => true}, :if => proc { |purchasable| (purchasable.quantity_enabled? rescue false) }

    scope :purchased, -> { joins(:order_items).joins(:orders).where(:orders => {:purchase_state => EffectiveOrders::PURCHASED}).uniq }
    scope :purchased_by, lambda { |user| joins(:order_items).joins(:orders).where(:orders => {:user_id => user.try(:id), :purchase_state => EffectiveOrders::PURCHASED}).uniq }
    scope :sold, -> { purchased() }
    scope :sold_by, lambda { |user| joins(:order_items).joins(:orders).where(:order_items => {:seller_id => user.try(:id)}).where(:orders => {:purchase_state => EffectiveOrders::PURCHASED}).uniq }

    scope :not_purchased, -> { where('id NOT IN (?)', purchased.pluck(:id).presence || [0]) }
  end

  module ClassMethods
    def after_purchase(&block)
      send :define_method, :after_purchase do |order, order_item| self.instance_exec(order, order_item, &block) end
    end

    def after_decline(&block)
      send :define_method, :after_decline do |order, order_item| self.instance_exec(order, order_item, &block) end
    end
  end

  # Regular instance methods
  def is_effectively_purchasable?
    true
  end

  def price
    self[:price] || 0.00
  end

  def title
    self[:title] || 'ActsAsPurchasable'
  end

  def tax_exempt
    self[:tax_exempt] || false
  end

  def tax_rate
    @tax_rate ||= (
      self.instance_exec(self, &EffectiveOrders.tax_rate_method).to_f.tap do |rate|
        raise ArgumentError.new("expected EffectiveOrders.tax_rate_method to return a value between 0 and 1. Received #{rate}. Please return 0.05 for 5% tax.") if (rate > 1.0 || rate < 0.0)
      end
    )
  end

  def seller
    if EffectiveOrders.stripe_connect_enabled
      raise 'acts_as_purchasable object requires the seller be defined to return the User selling this item.  This is only a requirement when using StripeConnect.'
    end
  end

  def quickbooks_item_name
    self[:quickbooks_item_name] || ''
  end

  def purchased?
    @is_purchased ||= orders.any? { |order| order.purchased? }
  end

  def purchased_by?(user)
    orders.any? { |order| order.purchased? && order.user_id == user.id }
  end

  def purchased_orders
    orders.select { |order| order.purchased? }
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

  def purchased!(order = nil, order_item = nil)
    # begin
    #   self.quantity_purchased = (self.quantity_purchased + 1)
    # rescue
    # end

    after_purchase(order, order_item) if self.respond_to?(:after_purchase)
    self.save!
  end

  def declined!(order = nil, order_item = nil)
    after_decline(order, order_item) if self.respond_to?(:after_decline)
    self.save!
  end

  # Override me if this is a digital purchase.
  def purchased_download_url
    false
  end

end

