module Effective
  class Order < ActiveRecord::Base
    self.table_name = EffectiveOrders.orders_table_name.to_s

    if EffectiveOrders.obfuscate_order_ids
      acts_as_obfuscated :format => '###-####-###'
    end

    acts_as_addressable(
      :billing => {
        :singular => true,
        :presence => EffectiveOrders.require_billing_address,
        :use_full_name => EffectiveOrders.use_address_full_name
      },
      :shipping => {
        :singular => true,
        :presence => EffectiveOrders.require_shipping_address,
        :use_full_name => EffectiveOrders.use_address_full_name
    })

    attr_accessor :save_billing_address, :save_shipping_address, :shipping_address_same_as_billing # save these addresses to the user if selected

    belongs_to :user  # This is the user who purchased the order
    has_many :order_items, :inverse_of => :order

    structure do
      payment         :text   # serialized hash, see below
      purchase_state  :string, :validates => [:inclusion => {:in => [nil, EffectiveOrders::PURCHASED, EffectiveOrders::DECLINED, EffectiveOrders::PENDING]}]
      purchased_at    :datetime, :validates => [:presence => {:if => Proc.new { |order| order.purchase_state == EffectiveOrders::PURCHASED}}]
      note            :text

      timestamps
    end

    accepts_nested_attributes_for :order_items, :allow_destroy => false, :reject_if => :all_blank
    accepts_nested_attributes_for :user, :allow_destroy => false, :update_only => true

    unless EffectiveOrders.skip_user_validation
      validates_presence_of :user_id
      validates_associated :user
    end

    if ((minimum_charge = EffectiveOrders.minimum_charge.to_i) rescue nil).present?
      if EffectiveOrders.allow_free_orders
        validates_numericality_of :total, :greater_than_or_equal_to => minimum_charge, :unless => Proc.new { |order| order.total == 0 }, :message => "A minimum order of #{EffectiveOrders.minimum_charge} is required.  Please add additional items to your cart."
      else
        validates_numericality_of :total, :greater_than_or_equal_to => minimum_charge, :message => "A minimum order of #{EffectiveOrders.minimum_charge} is required.  Please add additional items to your cart."
      end
    end

    validates_presence_of :order_items, :message => 'No items are present.  Please add one or more item to your cart.'
    validates_associated :order_items

    serialize :payment, Hash

    default_scope -> { includes(:user).includes(:order_items => :purchasable).order('created_at DESC') }

    scope :purchased, -> { where(:purchase_state => EffectiveOrders::PURCHASED) }
    scope :purchased_by, lambda { |user| purchased.where(:user_id => user.try(:id)) }
    scope :declined, -> { where(:purchase_state => EffectiveOrders::DECLINED) }

    # Can be an Effective::Cart, a single acts_as_purchasable, or an array of acts_as_purchasables
    def initialize(items = {}, user = nil)
      super() # Call super with no arguments

      # Set up defaults
      self.save_billing_address = true
      self.save_shipping_address = true
      self.shipping_address_same_as_billing = true

      self.user = (items.delete(:user) if items.kind_of?(Hash)) || user
      add_to_order(items) if items.present?
    end

    def add(item, quantity = 1)
      raise 'unable to alter a purchased order' if purchased?
      raise 'unable to alter a declined order' if declined?

      if item.kind_of?(Effective::Cart)
        cart_items = item.cart_items
      else
        purchasables = [item].flatten

        if purchasables.any? { |p| !p.respond_to?(:is_effectively_purchasable?) }
          raise ArgumentError.new('Effective::Order.add() expects a single acts_as_purchasable item, or an array of acts_as_purchasable items')
        end

        cart_items = purchasables.map do |purchasable|
          CartItem.new(:quantity => quantity).tap { |cart_item| cart_item.purchasable = purchasable }
        end

        # Initialize cart with user associated to order
        # This is useful when it is needed to get to associated user through cart object within application,
        # ex. in order to update tax rate considering associated user location (billing/shipping address)
        Cart.new(cart_items: cart_items, user: user) if user.present?
      end

      retval = cart_items.map do |item|
        order_items.build(
          :title => item.title,
          :quantity => item.quantity,
          :price => item.price,
          :tax_exempt => item.tax_exempt || false,
          :tax_rate => item.tax_rate,
          :seller_id => (item.purchasable.try(:seller).try(:id) rescue nil)
        ).tap { |order_item| order_item.purchasable = item.purchasable }
      end

      retval.size == 1 ? retval.first : retval
    end
    alias_method :add_to_order, :add

    def user=(user)
      return if user.nil?

      super

      # Copy user addresses into this order if they are present
      if user.respond_to?(:billing_address) && !user.billing_address.nil?
        self.billing_address = user.billing_address
      end

      if user.respond_to?(:shipping_address) && !user.shipping_address.nil?
        self.shipping_address = user.shipping_address
      end

      # If our addresses are required, make sure they exist
      if EffectiveOrders.require_billing_address
        self.billing_address ||= Effective::Address.new()
      end

      if EffectiveOrders.require_shipping_address
        self.shipping_address ||= Effective::Address.new()
      end

      # Ensure the Full Name is assigned when an address exists
      if billing_address.nil? == false && billing_address.full_name.blank?
        self.billing_address.full_name = billing_name
      end

      if shipping_address.nil? == false && shipping_address.full_name.blank?
        self.shipping_address.full_name = billing_name
      end
    end

    # This is used for updating Subscription codes.
    # We want to update the underlying purchasable object of an OrderItem
    # Passing the order_item_attributes using rails default acts_as_nested creates a new object instead of updating the temporary one.
    # So we override this method to do the updates on the non-persisted OrderItem objects
    # Right now strong_paramaters only lets through stripe_coupon_id
    # {"0"=>{"class"=>"Effective::Subscription", "stripe_coupon_id"=>"50OFF", "id"=>"2"}}}
    def order_items_attributes=(order_item_attributes)
      if self.persisted? == false
        (order_item_attributes || {}).each do |_, atts|
          order_item = self.order_items.find { |oi| oi.purchasable.class.name == atts[:class] && oi.purchasable.id == atts[:id].to_i }

          if order_item
            order_item.purchasable.attributes = atts.except(:id, :class)

            # Recalculate the OrderItem based on the updated purchasable object
            order_item.title = order_item.purchasable.title
            order_item.price = order_item.purchasable.price
            order_item.tax_exempt = order_item.purchasable.tax_exempt
            order_item.tax_rate = order_item.purchasable.tax_rate
            order_item.seller_id = (order_item.purchasable.try(:seller).try(:id) rescue nil)
          end
        end
      end
    end

    def total
      [order_items.map(&:total).sum, 0].max
    end

    def subtotal
      order_items.map(&:subtotal).sum
    end

    def tax
      [order_items.map(&:tax).sum, 0].max
    end

    def num_items
      order_items.map(&:quantity).sum
    end

    def save_billing_address?
      ::ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include?(self.save_billing_address)
    end

    def save_shipping_address?
      ::ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include?(self.save_shipping_address)
    end

    def shipping_address_same_as_billing?
      if self.shipping_address_same_as_billing.nil?
        true # Default value
      else
        ::ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include?(self.shipping_address_same_as_billing)
      end
    end

    def billing_name
      name ||= billing_address.try(:full_name).presence
      name ||= user.try(:full_name).presence
      name ||= (user.try(:first_name).to_s + ' ' + user.try(:last_name).to_s).presence
      name ||= user.try(:email).presence
      name ||= user.to_s
      name ||= "User #{user.try(:id)}"
      name
    end

    # :validate => false, :email => false
    def purchase!(payment_details = nil, opts = {})
      opts = {validate: true, email: true}.merge(opts)

      return false if purchased?
      raise EffectiveOrders::AlreadyDeclinedException.new('order already declined') if (declined? && opts[:validate])

      success = false

      Order.transaction do
        begin
          self.purchase_state = EffectiveOrders::PURCHASED
          self.purchased_at ||= Time.zone.now
          self.payment = payment_details.kind_of?(Hash) ? payment_details : {:details => (payment_details || 'none').to_s}

          save!(validate: opts[:validate])

          order_items.each { |item| (item.purchasable.purchased!(self, item) rescue nil) }

          success = true
        rescue => e
          raise ActiveRecord::Rollback
        end
      end

      send_order_receipts! if success && opts[:email]

      success
    end

    def decline!(payment_details = nil)
      return false if declined?

      raise EffectiveOrders::AlreadyPurchasedException.new('order already purchased') if purchased?

      Order.transaction do
        self.purchase_state = EffectiveOrders::DECLINED
        self.payment = payment_details.kind_of?(Hash) ? payment_details : {:details => (payment_details || 'none').to_s}

        order_items.each { |item| (item.purchasable.declined!(self, item) rescue nil) }

        save!
      end
    end

    def purchase_method
      return 'None' unless purchased?

      if purchased?(:stripe_connect)
        'Stripe Connect'
      elsif purchased?(:stripe)
        'Stripe'
      elsif purchased?(:moneris)
        'Moneris'
      elsif purchased?(:paypal)
        'PayPal'
      else
        'Online'
      end
    end
    alias_method :payment_method, :purchase_method

    def purchase_card_type
      return 'None' unless purchased?

      if purchased?(:stripe_connect)
        ((payment[:charge] || payment['charge'])['card']['brand'] rescue 'Unknown')
      elsif purchased?(:stripe)
        ((payment[:charge] || payment['charge'])['card']['brand'] rescue 'Unknown')
      elsif purchased?(:moneris)
        payment[:card] || payment['card'] || 'Unknown'
      elsif purchased?(:paypal)
        payment[:payment_type] || payment['payment_type'] || 'Unknown'
      else
        'Online'
      end
    end
    alias_method :payment_card_type, :purchase_card_type

    def purchased?(provider = nil)
      return false if (purchase_state != EffectiveOrders::PURCHASED)
      return true if provider == nil || payment.kind_of?(Hash) == false

      case provider.to_sym
      when :stripe_connect
        charge = (payment[:charge] || payment['charge'] || {})
        charge['id'] && charge['customer'] && charge['application_fee'].present?
      when :stripe
        charge = (payment[:charge] || payment['charge'] || {})
        charge['id'] && charge['customer']
      when :moneris
        (payment[:response_code] || payment['response_code']) &&
        (payment[:transactionKey] || payment['transactionKey'])
      when :paypal
        (payment[:payer_email] || payment['payer_email'])
      else
        raise "Unknown provider #{provider} passed to Effective::Order.purchased?"
      end
    end

    def declined?
      purchase_state == EffectiveOrders::DECLINED
    end

    def pending?
      purchase_state == EffectiveOrders::PENDING
    end

    def send_order_receipts!
      send_order_receipt_to_admin!
      send_order_receipt_to_buyer!
      send_order_receipt_to_seller!
    end

    def send_order_receipt_to_admin!
      return false unless purchased? && EffectiveOrders.mailer[:send_order_receipt_to_admin]
      send_email(:order_receipt_to_admin, self)
    end

    def send_order_receipt_to_buyer!
      return false unless purchased? && EffectiveOrders.mailer[:send_order_receipt_to_buyer]
      send_email(:order_receipt_to_buyer, self)
    end

    def send_payment_request_to_buyer!
      return false unless !purchased? && EffectiveOrders.mailer[:send_payment_request_to_buyer]
      send_email(:payment_request_to_buyer, self)
    end

    def send_order_receipt_to_seller!
      return false unless purchased?(:stripe_connect) && EffectiveOrders.mailer[:send_order_receipt_to_seller]

      order_items.group_by(&:seller).each do |seller, order_items|
        send_email(:order_receipt_to_seller, self, seller, order_items)
      end
    end

  private

    def send_email(email, *mailer_args)
      begin
        if EffectiveOrders.mailer[:delayed_job_deliver] && EffectiveOrders.mailer[:deliver_method] == :deliver_later
          (OrdersMailer.delay.public_send(email, *mailer_args) rescue false)
        else
          (OrdersMailer.public_send(email, *mailer_args).public_send(EffectiveOrders.mailer[:deliver_method]) rescue false)
        end
      rescue => e
        raise e unless Rails.env.production?
        return false
      end
    end
  end
end
