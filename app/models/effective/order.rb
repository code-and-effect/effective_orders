module Effective
  class Order < ActiveRecord::Base
    self.table_name = EffectiveOrders.orders_table_name.to_s

    acts_as_addressable :billing => EffectiveOrders.require_billing_address, :shipping => EffectiveOrders.require_shipping_address
    attr_accessor :save_billing_address, :save_shipping_address # Save these addresses to the user if selected

    belongs_to :user  # This is the user who purchased the order
    has_many :order_items, :inverse_of => :order

    structure do
      payment         :text   # serialized hash, see below
      purchase_state  :string, :validates => [:inclusion => {:in => [nil, EffectiveOrders::PURCHASED, EffectiveOrders::DECLINED]}]
      purchased_at    :datetime, :validates => [:presence => {:if => Proc.new { |order| order.purchase_state == EffectiveOrders::PURCHASED}}]

      timestamps
    end

    accepts_nested_attributes_for :order_items, :allow_destroy => false, :reject_if => :all_blank
    validates_presence_of :user_id
    validates_presence_of :order_items, :message => 'An order must contain order items.  Please add one or more items to your Cart before proceeding to checkout.'

    serialize :payment, Hash

    default_scope includes(:user).includes(:order_items => :purchasable).order('created_at DESC')

    scope :purchased, -> { where(:purchase_state => EffectiveOrders::PURCHASED) }
    scope :purchased_by, lambda { |user| purchased.where(:user_id => user.try(:id)) }
    scope :declined, -> { where(:purchase_state => EffectiveOrders::DECLINED) }

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
            :purchasable_type => item.purchasable_type,
            :seller_id => (item.purchasable.try(:seller).try(:id) rescue nil)
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

    def num_items
      order_items.to_a.sum(&:quantity)
    end

    def purchase!(payment_details = nil)
      raise EffectiveOrders::AlreadyPurchasedException.new('order already purchased') if self.purchased?

      Order.transaction do
        self.purchase_state = EffectiveOrders::PURCHASED
        self.purchased_at = Time.now
        self.payment = payment_details.kind_of?(Hash) ? payment_details : {:details => (payment_details || 'none').to_s}

        order_items.each { |item| item.purchased(self) }

        self.save!

        if EffectiveOrders.mailer[:send_order_receipt_to_admin]
          OrdersMailer.order_receipt_to_admin(self).deliver rescue false
        end

        if EffectiveOrders.mailer[:send_order_receipt_to_buyer]
          OrdersMailer.order_receipt_to_buyer(self).deliver rescue false
        end

        if EffectiveOrders.mailer[:send_order_receipt_to_seller] && self.purchased?(:stripe_connect)
          self.order_items.group_by(&:seller).each do |seller, order_items|
            OrdersMailer.order_receipt_to_seller(self, seller, order_items).deliver rescue false
          end
        end
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

    def purchased?(provider = nil)
      return false if (purchase_state != EffectiveOrders::PURCHASED)

      begin
        case provider
        when nil
          true
        when :stripe_connect
          payment.keys.first.kind_of?(Numeric) && payment[payment.keys.first].key?('object') && payment[payment.keys.first]['object'] == 'charge'
        when :stripe
          payment.key?('object') && payment['object'] == 'charge'
        when :moneris
        when :paypal
        else
          false
        end
      rescue => e
        false
      end
    end

    def declined?
      purchase_state == EffectiveOrders::DECLINED
    end

  end
end
