module Effective
  class Order < ActiveRecord::Base
    self.table_name = EffectiveOrders.orders_table_name.to_s

    acts_as_addressable :billing => EffectiveOrders.require_billing_address, :shipping => EffectiveOrders.require_shipping_address
    attr_accessor :save_billing_address, :save_shipping_address # Save these addresses to the user if selected

    belongs_to :user
    has_many :order_items

    structure do
      details         :text   # This is a log of order details and changes
      payment         :text   # serialized hash, see below
      purchase_state  :string, :validates => [:inclusion => {:in => [nil, EffectiveOrders::PURCHASED, EffectiveOrders::DECLINED]}]
      purchased_at    :datetime, :validates => [:presence => {:if => Proc.new { |order| order.purchase_state == EffectiveOrders::PURCHASED}}]

      timestamps
    end

    accepts_nested_attributes_for :order_items, :allow_destroy => false, :reject_if => :all_blank
    validates_presence_of :user_id
    validates_presence_of :order_items, :message => 'An order must contain order items.  Please add one or more items to your Cart before proceeding to checkout.'

    store :payment # ActiveRecord::Store to serialize a Hash and store the results of payment

    default_scope includes(:order_items => :purchasable).order('created_at DESC')

    def initialize(cart = {})
      if cart.kind_of?(Effective::Cart)
        super() # Call super with no arguments

        cart.cart_items.each do |item|
          self.order_items.build(
            :title => item.title,
            :quantity => item.quantity,
            :price => item.price,
            :tax_exempt => item.tax_exempt,
            :tax_rate => item.tax_rate,
            :quickbooks_item_name => item.quickbooks_item_name,
            :purchasable_id => item.purchasable_id,
            :purchasable_type => item.purchasable_type
          )
        end
      else
        super # Call super as normal
      end
    end

    def buyer
      @buyer ||= Effective::Customer.for_user(user)
    end

    def total
      order_items.collect(&:total).sum
    end

    def subtotal
      order_items.collect(&:subtotal).sum
    end

    def tax
      order_items.collect(&:tax).sum
    end

    def purchase!(payment_details = nil)
      raise EffectiveOrders::AlreadyPurchasedException.new('order already purchased') if self.purchased?

      Order.transaction do
        self.purchase_state = EffectiveOrders::PURCHASED
        self.purchased_at = Time.now
        self.payment = payment_details.kind_of?(Hash) ? payment_details : {:details => (payment_details || 'none').to_s}

        order_items.each { |item| item.purchased(self) }

        self.save!

        #DelayedJob.new.send_email('successful_order_to_user', self) if SiteConfiguration.email_receipt_to_user_on_successful_order?
        #DelayedJob.new.send_email('successful_order_to_admin', self) if SiteConfiguration.email_receipt_to_admin_on_successful_order?
      end
    end

    def decline!(payment_details = nil)
      raise EffectiveOrders::AlreadyDeclinedException.new('order already declined') if self.declined?

      Order.transaction do
        self.purchase_state = EffectiveOrders::DECLINED
        self.payment = payment_details.kind_of?(Hash) ? payment_details : {:details => (payment_details || 'none').to_s}

        order_items.each { |item| item.declined(self) }

        self.save!
      end
    end

    def purchased?
      purchase_state == EffectiveOrders::PURCHASED
    end

    def declined?
      purchase_state == EffectiveOrders::DECLINED
    end

  end
end
