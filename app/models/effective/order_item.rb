module Effective
  class OrderItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.order_items_table_name.to_s

    belongs_to :order

    belongs_to :purchasable, polymorphic: true
    accepts_nested_attributes_for :purchasable, allow_destroy: false

    if defined?(EffectiveQbSync)
      has_one :qb_order_item
    end

    effective_resource do
      name                  :string
      quantity              :integer
      price                 :integer
      tax_exempt            :boolean

      timestamps
    end

    scope :purchased, -> { where(order_id: Effective::Order.purchased) }
    scope :purchased_by, lambda { |user| where(order_id: Effective::Order.purchased_by(user)) }

    validates :name, presence: true
    validates :quantity, presence: true, numericality: { greater_than: 0 }
    validates :price, presence: true
    validates :tax_exempt, inclusion: { in: [true, false] }

    def to_s
      ((quantity || 0) > 1 ? "#{quantity}x #{name}" : name) || 'order item'
    end

    # This method is called in a before_validation in order.assign_order_totals()
    def assign_purchasable_attributes
      assign_attributes(name: purchasable.purchasable_name, price: purchasable.price, tax_exempt: purchasable.tax_exempt) if purchasable
    end

    def build_purchasable(atts = {})
      (self.purchasable ||= Effective::Product.new).tap { |purchasable| purchasable.assign_attributes(atts) }
    end

    def purchased_download_url
      purchasable&.purchased_download_url
    end

    def subtotal
      price * quantity
    end

    def quantity
      self[:quantity] || 1
    end

    def tax
      return 0 if tax_exempt?
      raise 'parent Effective::Order must have a tax_rate to compute order item tax' unless order.try(:tax_rate).present?
      (subtotal * order.tax_rate / 100.0).round(0).to_i
    end

    def total
      return subtotal if tax_exempt?
      raise 'parent Effective::Order must have a tax_rate to compute order item total' unless order.try(:tax_rate).present?
      subtotal + tax
    end

    def price=(value)
      raise 'expected price to be an Integer representing the number of cents.' unless value.kind_of?(Integer)
      super
    end

    # first or build
    def qb_item_name
      raise('expected Effective Quickbooks gem') unless defined?(EffectiveQbSync) || defined?(EffectiveQbOnline)
      (qb_order_item || build_qb_order_item(name: purchasable&.qb_item_name)).name
    end

  end
end
