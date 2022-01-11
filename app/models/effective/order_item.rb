module Effective
  class OrderItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.order_items_table_name.to_s

    belongs_to :order
    belongs_to :purchasable, polymorphic: true

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

    validates :purchasable, associated: true, presence: true
    accepts_nested_attributes_for :purchasable

    validates :name, presence: true
    validates :quantity, presence: true, numericality: { greater_than: 0 }
    validates :price, presence: true
    validates :tax_exempt, inclusion: { in: [true, false] }

    scope :purchased, -> { where(order_id: Effective::Order.purchased) }
    scope :purchased_by, lambda { |user| where(order_id: Effective::Order.purchased_by(user)) }

    def to_s
      ((quantity || 0) > 1 ? "#{quantity}x #{name}" : name) || 'order item'
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
      if value.kind_of?(Integer)
        super
      else
        raise 'expected price to be an Integer representing the number of cents.'
      end
    end

    # first or build
    def qb_item_name
      raise('expected EffectiveQbSync gem') unless defined?(EffectiveQbSync)
      (qb_order_item || build_qb_order_item(name: purchasable&.qb_item_name)).name
    end

  end
end
