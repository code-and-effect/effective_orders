module Effective
  class OrderItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.order_items_table_name.to_s

    belongs_to :order
    belongs_to :purchasable, :polymorphic => true
    belongs_to :seller, :class_name => 'User'

    delegate :purchased_download_url, :to => :purchasable
    delegate :purchased?, :declined?, :to => :order

    structure do
      title                 :string
      quantity              :integer
      price                 :integer, default: 0
      tax_exempt            :boolean

      timestamps
    end

    validates :purchasable, associated: true, presence: true
    accepts_nested_attributes_for :purchasable, allow_destroy: false, reject_if: :all_blank, update_only: true

    validates :title, presence: true
    validates :quantity, presence: true, numericality: { greater_than: 0 }
    validates :price, numericality: true
    validates :tax_exempt, inclusion: { in: [true, false] }

    validates :seller_id, presence: true, if: Proc.new { |order_item| EffectiveOrders.stripe_connect_enabled }

    scope :sold, -> { joins(:order).where(:orders => {:purchase_state => EffectiveOrders::PURCHASED}) }
    scope :sold_by, lambda { |user| sold().where(:seller_id => user.try(:id)) }

    def to_s
      (quantity || 0) > 1 ? "#{quantity}x #{title}" : title
    end

    def subtotal
      price * quantity
    end
    alias_method :total, :subtotal

    def price=(value)
      if value.kind_of?(Integer)
        super
      elsif value.kind_of?(String) && !value.include?('.') # Looks like an integer
        super
      else # Could be Float, BigDecimal, or String like 9.99
        ActiveSupport::Deprecation.warn('order_item.price= was passed a non-integer. Expecting an Integer representing the number of cents.  Continuing with (price * 100.0).round(0).to_i conversion') unless EffectiveOrders.silence_deprecation_warnings
        super((value.to_f * 100.0).to_i)
      end
    end

    # This is going to return an Effective::Customer object that matches the purchasable.user
    # And is the Customer representing who is selling the product
    # This is really only used for StripeConnect
    def seller
      @seller ||= Effective::Customer.for_user(purchasable.try(:seller))
    end

    def stripe_connect_application_fee
      @stripe_connect_application_fee ||= (
        self.instance_exec(self, &EffectiveOrders.stripe_connect_application_fee_method).to_i.tap do |fee|
          raise ArgumentError.new("expected EffectiveOrders.stripe_connect_application_fee_method to return a value between 0 and the order_item total (#{self.total}).  Received #{fee}.") if (fee > total || fee < 0)
        end
      )
    end
  end
end
