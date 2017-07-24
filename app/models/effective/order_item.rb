module Effective
  class OrderItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.order_items_table_name.to_s

    belongs_to :order, class_name: 'Effective::Order'
    belongs_to :purchasable, polymorphic: true
    belongs_to :seller, class_name: 'User'

    delegate :purchased_download_url, to: :purchasable
    delegate :purchased?, :declined?, to: :order

    # Attributes
    # title                 :string
    # quantity              :integer
    # price                 :integer, default: 0
    # tax_exempt            :boolean
    # timestamps

    validates :purchasable, associated: true, presence: true
    accepts_nested_attributes_for :purchasable, allow_destroy: false, reject_if: :all_blank, update_only: true

    validates :title, presence: true
    validates :quantity, presence: true, numericality: { greater_than: 0 }
    validates :price, presence: true
    validates :tax_exempt, inclusion: { in: [true, false] }

    validates :seller_id, presence: true, if: -> { EffectiveOrders.stripe_connect_enabled }

    scope :sold, -> { joins(:order).where(orders: { purchase_state: EffectiveOrders::PURCHASED }) }
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
      elsif value.kind_of?(String) && !value.include?('.') # Looks like an integer
        super
      else # Could be Float, BigDecimal, or String like 9.99
        raise 'expected price to be an Integer representing the number of cents.'
      end
    end

    # This is going to return an Effective::Customer object that matches the purchasable.user
    # And is the Customer representing who is selling the product
    # This is really only used for StripeConnect
    def seller
      @seller ||= Effective::Customer.for(purchasable.seller)
    end

    def stripe_connect_application_fee
      @stripe_connect_application_fee ||= (
        self.instance_exec(self, &EffectiveOrders.stripe_connect_application_fee_method).to_i.tap do |fee|
          raise "expected EffectiveOrders.stripe_connect_application_fee_method to return a value between 0 and the order_item total (#{self.total}). Received #{fee}." if (fee > total || fee < 0)
        end
      )
    end
  end
end
