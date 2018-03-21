module Effective
  class OrderItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.order_items_table_name.to_s

    belongs_to :order, class_name: 'Effective::Order'
    belongs_to :purchasable, polymorphic: true

    delegate :purchased_download_url, to: :purchasable
    delegate :purchased?, :declined?, to: :order

    # Attributes
    # title                 :string
    # quantity              :integer
    # price                 :integer, default: 0
    # tax_exempt            :boolean
    # timestamps

    validates :purchasable, associated: true, presence: true
    accepts_nested_attributes_for :purchasable

    validates :title, presence: true
    validates :quantity, presence: true, numericality: { greater_than: 0 }
    validates :price, presence: true
    validates :tax_exempt, inclusion: { in: [true, false] }

    scope :sold, -> { joins(:order).where(orders: { state: EffectiveOrders::PURCHASED }) }
    scope :sold_by, lambda { |user| sold().where(seller_id: user.id) }

    def to_s
      (quantity || 0) > 1 ? "#{quantity}x #{title}" : title
    end

    def subtotal
      price * quantity
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

  end
end
