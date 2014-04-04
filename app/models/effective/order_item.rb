module Effective
  class OrderItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.order_items_table_name.to_s

    belongs_to :order
    belongs_to :purchasable, :polymorphic => true
    belongs_to :seller, :class_name => 'User'

    structure do
      title                 :string, :validates => [:presence]
      quantity              :integer, :validates => [:presence, :numericality => {:greater_than => 0}]
      price                 :decimal, :precision => 8, :scale => 2, :default => 0.00
      tax_exempt            :boolean, :validates => [:inclusion => {:in => [true, false]}]
      tax_rate              :decimal, :precision => 5, :scale => 3, :default => 0.000, :validates => [:presence]
      quickbooks_item_name  :string

      timestamps
    end

    validates_presence_of :seller_id, :if => Proc.new { |order_item| EffectiveOrders.stripe_connect_enabled }

    delegate :purchased?, :declined?, :to => :order
    delegate :purchased_download_url, :to => :purchasable
    delegate :purchased, :declined, :to => :purchasable # Callbacks

    scope :sold, -> { joins(:order).where(:orders => {:purchase_state => EffectiveOrders::PURCHASED}) }
    scope :sold_by, lambda { |user| sold().where(:seller_id => user.try(:id)) }

    def subtotal
      price * quantity
    end

    def tax  # This is the total tax, for 3 items if quantity is 3
      tax_exempt ? 0.00 : (subtotal * tax_rate)
    end

    def total
      subtotal + tax
    end

    # This is going to return an Effective::Customer object that matches the purchasable.user
    # And is the Customer representing who is selling the product
    # This is really only used for StripeConnect
    def seller
      @seller ||= Effective::Customer.for_user(purchasable.try(:seller))
    end

    def stripe_connect_application_fee
      @stripe_connect_application_fee ||= (
        self.instance_exec(self, &EffectiveOrders.stripe_connect_application_fee_method).to_f.tap do |fee|
          raise ArgumentError.new("expected EffectiveOrders.stripe_connect_application_fee_method to return a value between 0 and the order_item total (#{self.total}).  Received #{fee}.") if (fee > total || fee < 0.0)
        end
      )
    end
  end
end
