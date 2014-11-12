module Effective
  class OrderItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.order_items_table_name.to_s

    belongs_to :order
    belongs_to :purchasable, :polymorphic => true
    belongs_to :seller, :class_name => 'User'

    structure do
      title                 :string, :validates => [:presence]
      quantity              :integer, :validates => [:presence, :numericality]
      price                 :integer, :default => 0, :validates => [:numericality]
      tax_exempt            :boolean, :validates => [:inclusion => {:in => [true, false]}]
      tax_rate              :decimal, :precision => 5, :scale => 3, :default => 0.000, :validates => [:presence]

      timestamps
    end

    validates_associated :purchasable
    validates_presence_of :purchasable
    accepts_nested_attributes_for :purchasable, :allow_destroy => false, :reject_if => :all_blank, :update_only => true

    validates_presence_of :seller_id, :if => Proc.new { |order_item| EffectiveOrders.stripe_connect_enabled }

    delegate :purchased_download_url, :to => :purchasable
    delegate :purchased?, :declined?, :to => :order

    scope :sold, -> { joins(:order).where(:orders => {:purchase_state => EffectiveOrders::PURCHASED}) }
    scope :sold_by, lambda { |user| sold().where(:seller_id => user.try(:id)) }

    def subtotal
      price * quantity
    end

    def tax  # This is the total tax, for 3 items if quantity is 3
      tax_exempt ? 0 : (subtotal * tax_rate).floor
    end

    def total
      subtotal + tax
    end

    def price=(value)
      if value.kind_of?(Integer)
        super
      elsif value.kind_of?(String) && !value.include?('.') # Looks like an integer
        super
      else # Could be Float, BigDecimal, or String like 9.99
        ActiveSupport::Deprecation.warn('order_item.price= was passed a non-integer. Expecting an Integer representing the number of cents.  Continuing with (price * 100.0).floor conversion') unless EffectiveOrders.silence_deprecation_warnings
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
