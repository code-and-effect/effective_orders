# When an Order is first initialized it is done in the pending state
# - when it's in the pending state, none of the buyer entered information is required
# - when a pending order is rendered:
# - if the user has a billing address, go to step 2
# - if the user has no billing address, go to step 1
#
# After Step1, we go to the confirmed state
# After Step2, we are in the purchased or declined state

module Effective
  class Order < ActiveRecord::Base
    self.table_name = EffectiveOrders.orders_table_name.to_s

    if EffectiveOrders.obfuscate_order_ids
      acts_as_obfuscated format: '###-####-###'
    end

    acts_as_addressable(
      billing: { singular: true, use_full_name: EffectiveOrders.use_address_full_name },
      shipping: { singular: true, use_full_name: EffectiveOrders.use_address_full_name }
    )

    attr_accessor :terms_and_conditions # Yes, I agree to the terms and conditions
    attr_accessor :confirmed_checkout   # Set on the Checkout Step 1

    # Settings in the /admin action forms
    attr_accessor :send_payment_request_to_buyer # Set by Admin::Orders#new. Should the payment request email be sent after creating an order?
    attr_accessor :send_mark_as_paid_email_to_buyer  # Set by Admin::Orders#mark_as_paid
    attr_accessor :skip_buyer_validations # Set by Admin::Orders#create

    # If we want to use orders in a has_many way
    belongs_to :parent, polymorphic: true, optional: true

    belongs_to :user, polymorphic: true, validate: false  # This is the buyer/user of the order. We validate it below.
    has_many :order_items, -> { order(:id) }, inverse_of: :order, dependent: :delete_all

    accepts_nested_attributes_for :order_items, allow_destroy: false, reject_if: :all_blank
    accepts_nested_attributes_for :user, allow_destroy: false, update_only: true

    # Attributes
    effective_resource do
      state             :string
      purchased_at      :datetime

      note              :text   # From buyer to admin
      note_to_buyer     :text   # From admin to buyer
      note_internal     :text   # Internal admin only

      billing_name      :string   # name of buyer
      email             :string   # same as user.email
      cc                :string   # can be set by admin

      payment           :text     # serialized hash containing all the payment details.
      payment_provider  :string
      payment_card      :string

      tax_rate          :decimal, precision: 6, scale: 3

      subtotal          :integer
      tax               :integer
      total             :integer

      timestamps
    end

    serialize :payment, Hash

    before_validation { assign_order_totals }
    before_validation { assign_billing_name }
    before_validation { assign_email }
    before_validation { assign_last_address }

    before_validation(if: -> { confirmed_checkout }) do
      self.state = EffectiveOrders::CONFIRMED if pending?
    end

    before_save(if: -> { state_was == EffectiveOrders::PURCHASED }) do
      raise EffectiveOrders::AlreadyPurchasedException.new('cannot unpurchase an order') unless purchased?
    end

    # Order validations
    validates :user_id, presence: true
    validates :email, presence: true, email: true  # email and cc validators are from effective_resources
    validates :cc, email_cc: true

    validates :order_items, presence: { message: 'No items are present. Please add additional items.' }
    validates :state, inclusion: { in: EffectiveOrders::STATES.keys }
    validates :subtotal, presence: true

    if EffectiveOrders.minimum_charge.to_i > 0
      validates :total, presence: true, numericality: {
        greater_than_or_equal_to: EffectiveOrders.minimum_charge.to_i,
        message: "must be $#{'%0.2f' % (EffectiveOrders.minimum_charge.to_i / 100.0)} or more. Please add additional items."
      }, unless: -> { (free? && EffectiveOrders.free?) || (refund? && EffectiveOrders.refund?) }
    end

    validate(if: -> { tax_rate.present? }) do
      if (tax_rate > 100.0 || (tax_rate < 0.25 && tax_rate > 0.0000))
        errors.add(:tax_rate, "is invalid. expected a value between 100.0 (100%) and 0.25 (0.25%) or 0")
      end
    end

    # User validations -- An admin skips these when working in the admin/ namespace
    with_options unless: -> { pending? || skip_buyer_validations? } do
      validates :tax_rate, presence: { message: "can't be determined based on billing address" }
      validates :tax, presence: true

      if EffectiveOrders.billing_address
        validates :billing_address, presence: true
      end

      if EffectiveOrders.shipping_address
        validates :shipping_address, presence: true
      end

      if EffectiveOrders.collect_note_required
        validates :note, presence: true
      end
    end

    with_options if: -> { confirmed? && !skip_buyer_validations? } do
      if EffectiveOrders.terms_and_conditions
        validates :terms_and_conditions, presence: true
      end
    end

    # When Purchased
    with_options if: -> { purchased? } do
      validates :purchased_at, presence: true
      validates :payment, presence: true

      validates :payment_provider, presence: true, inclusion: { in: EffectiveOrders.payment_providers }
      validates :payment_card, presence: true
    end

    with_options if: -> { deferred? } do
      validates :payment_provider, presence: true, inclusion: { in: EffectiveOrders.deferred_providers }
    end

    scope :deep, -> { includes(:addresses, :user, order_items: :purchasable) }
    scope :sorted, -> { order(:id) }

    scope :purchased, -> { where(state: EffectiveOrders::PURCHASED) }
    scope :purchased_by, lambda { |user| purchased.where(user: user) }
    scope :not_purchased, -> { where.not(state: EffectiveOrders::PURCHASED) }

    scope :pending, -> { where(state: EffectiveOrders::PENDING) }
    scope :confirmed, -> { where(state: EffectiveOrders::CONFIRMED) }
    scope :deferred, -> { where(state: EffectiveOrders::DEFERRED) }
    scope :declined, -> { where(state: EffectiveOrders::DECLINED) }
    scope :refunds, -> { purchased.where('total < ?', 0) }

    # Effective::Order.new()
    # Effective::Order.new(Product.first)
    # Effective::Order.new(current_cart)
    # Effective::Order.new(Effective::Order.last)

    # Effective::Order.new(items: Product.first)
    # Effective::Order.new(items: [Product.first, Product.second], user: User.first)
    # Effective::Order.new(items: Product.first, user: User.first, billing_address: Effective::Address.new, shipping_address: Effective::Address.new)

    def initialize(atts = nil, &block)
      super(state: EffectiveOrders::PENDING) # Initialize with state: PENDING

      return unless atts.present?

      if atts.kind_of?(Hash)
        items = Array(atts.delete(:item)) + Array(atts.delete(:items))

        self.user = atts.delete(:user) || (items.first.user if items.first.respond_to?(:user))

        if (address = atts.delete(:billing_address)).present?
          self.billing_address = address
          self.billing_address.full_name ||= user.to_s.presence
        end

        if (address = atts.delete(:shipping_address)).present?
          self.shipping_address = address
          self.shipping_address.full_name ||= user.to_s.presence
        end

        atts.each { |key, value| self.send("#{key}=", value) }

        add(items) if items.present?
      else # Attributes are not a Hash
        self.user = atts.user if atts.respond_to?(:user)
        add(atts)
      end
    end

    # Items can be an Effective::Cart, an Effective::order, a single acts_as_purchasable, or multiple acts_as_purchasables
    # add(Product.first) => returns an Effective::OrderItem
    # add(Product.first, current_cart) => returns an array of Effective::OrderItems
    def add(*items, quantity: 1)
      raise 'unable to alter a purchased order' if purchased?
      raise 'unable to alter a declined order' if declined?

      cart_items = items.flatten.flat_map do |item|
        if item.kind_of?(Effective::Cart)
          item.cart_items.to_a
        elsif item.kind_of?(ActsAsPurchasable)
          Effective::CartItem.new(quantity: quantity, purchasable: item)
        elsif item.kind_of?(Effective::Order)
          # Duplicate an existing order
          self.note_to_buyer ||= item.note_to_buyer
          self.note_internal ||= item.note_internal

          item.order_items.select { |oi| oi.purchasable.kind_of?(Effective::Product) }.map do |oi|
            product = Effective::Product.new(name: oi.purchasable.purchasable_name, price: oi.purchasable.price, tax_exempt: oi.purchasable.tax_exempt)
            Effective::CartItem.new(quantity: oi.quantity, purchasable: product)
          end
        else
          raise 'add() expects one or more acts_as_purchasable objects, or an Effective::Cart'
        end
      end.compact

      # Make sure to reset stored aggregates
      self.total = nil
      self.subtotal = nil
      self.tax = nil

      retval = cart_items.map do |item|
        order_items.build(
          name: item.name,
          quantity: item.quantity,
          price: item.price,
          tax_exempt: (item.tax_exempt || false),
        ).tap { |order_item| order_item.purchasable = item.purchasable }
      end

      retval.size == 1 ? retval.first : retval
    end


    def update_prices!
      raise('already purchased') if purchased?
      raise('must be pending or confirmed') unless pending? || confirmed?

      order_items.each do |item|
        purchasable = item.purchasable

        if purchasable.blank? || purchasable.marked_for_destruction?
          item.mark_for_destruction
        else
          item.price = purchasable.price
        end
      end

      save!
    end

    def to_s
      [label, ' #', to_param].join
    end

    def label
      if refund?
        "Refund"
      elsif purchased?
        "Receipt"
      elsif pending?
        "Pending Order"
      else
        "Order"
      end
    end

    # Visa - 1234
    def payment_method
      return nil unless purchased?

      # Normalize payment card
      card = case payment_card.to_s.downcase.gsub(' ', '').strip
        when '' then nil
        when 'v', 'visa' then 'Visa'
        when 'm', 'mc', 'master', 'mastercard' then 'MasterCard'
        when 'a', 'ax', 'american', 'americanexpress' then 'American Express'
        when 'd', 'discover' then 'Discover'
        else payment_card.to_s
      end unless payment_provider == 'free'

      # stripe, moneris, moneris_checkout
      last4 = (payment[:active_card] || payment['f4l4'] || payment['first6last4']).to_s.last(4)

      [card, '-', last4].compact.join(' ')
    end

    # For moneris and moneris_checkout. Just a unique value.
    def transaction_id
      [to_param, billing_name.to_s.parameterize.presence, Time.zone.now.to_i].compact.join('-')
    end

    def billing_first_name
      billing_name.to_s.split(' ').first
    end

    def billing_last_name
      Array(billing_name.to_s.split(' ')[1..-1]).join(' ')
    end

    def pending?
      state == EffectiveOrders::PENDING
    end

    def confirmed?
      state == EffectiveOrders::CONFIRMED
    end

    def deferred?
      state == EffectiveOrders::DEFERRED
    end

    def purchased?(provider = nil)
      return false if (state != EffectiveOrders::PURCHASED)
      return true if provider.nil? || payment_provider == provider.to_s
      false
    end

    def declined?
      state == EffectiveOrders::DECLINED
    end

    def purchasables
      order_items.map { |order_item| order_item.purchasable }
    end

    def subtotal
      self[:subtotal] || order_items.map { |oi| oi.subtotal }.sum
    end

    def tax_rate
      self[:tax_rate] || get_tax_rate()
    end

    def tax
      self[:tax] || get_tax()
    end

    def total
      (self[:total] || (subtotal + tax.to_i)).to_i
    end

    def free?
      total == 0
    end

    def refund?
      total.to_i < 0
    end

    def num_items
      order_items.map { |oi| oi.quantity }.sum
    end

    def send_payment_request_to_buyer?
      EffectiveResources.truthy?(send_payment_request_to_buyer) && !free? && !refund?
    end

    def send_mark_as_paid_email_to_buyer?
      EffectiveResources.truthy?(send_mark_as_paid_email_to_buyer)
    end

    def skip_buyer_validations?
      EffectiveResources.truthy?(skip_buyer_validations)
    end

    # This is called from admin/orders#create
    # This is intended for use as an admin action only
    # It skips any address or bad user validations
    # It's basically the same as save! on a new order, except it might send the payment request to buyer
    def pending!
      return false if purchased?

      self.state = EffectiveOrders::PENDING
      self.addresses.clear if addresses.any? { |address| address.valid? == false }
      save!

      send_payment_request_to_buyer! if send_payment_request_to_buyer?
      true
    end

    # Used by admin checkout only
    def confirm!
      return false if purchased?
      update!(state: EffectiveOrders::CONFIRMED)
    end

    # This lets us skip to the confirmed workflow for an admin...
    def assign_confirmed_if_valid!
      return unless pending?

      self.state = EffectiveOrders::CONFIRMED
      return true if valid?

      self.errors.clear
      self.state = EffectiveOrders::PENDING
      false
    end

    # Effective::Order.new(items: Product.first, user: User.first).purchase!(email: false)
    def purchase!(payment: 'none', provider: 'none', card: 'none', email: true, skip_buyer_validations: false)
      # Assign attributes
      self.state = EffectiveOrders::PURCHASED
      self.skip_buyer_validations = skip_buyer_validations

      self.payment_provider ||= provider
      self.payment_card ||= (card.presence || 'none')
      self.purchased_at ||= Time.zone.now
      self.payment = payment_to_h(payment) if self.payment.blank?

      begin
        Effective::Order.transaction do
          run_purchasable_callbacks(:before_purchase)
          save!
          update_purchasables_purchased_order!
        end
      rescue => e
        Effective::Order.transaction do
          save!(validate: false)
          update_purchasables_purchased_order!
        end

        raise(e)
      end

      run_purchasable_callbacks(:after_purchase)
      send_order_receipts! if email

      true
    end

    def defer!(provider: 'none', email: true)
      return false if purchased?

      assign_attributes(
        state: EffectiveOrders::DEFERRED,
        payment_provider: provider
      )

      save!

      send_payment_request_to_buyer! if email

      true
    end

    def decline!(payment: 'none', provider: 'none', card: 'none', validate: true)
      return false if declined?

      raise EffectiveOrders::AlreadyPurchasedException.new('order already purchased') if purchased?

      error = nil

      assign_attributes(
        state: EffectiveOrders::DECLINED,
        purchased_at: nil,
        payment: payment_to_h(payment),
        payment_provider: provider,
        payment_card: (card.presence || 'none'),
        skip_buyer_validations: true
      )

      Effective::Order.transaction do
        begin
          save!(validate: validate)
        rescue => e
          self.state = state_was

          error = e.message
          raise ::ActiveRecord::Rollback
        end
      end

      raise "Failed to decline order: #{error || errors.full_messages.to_sentence}" unless error.nil?

      run_purchasable_callbacks(:after_decline)

      true
    end

    # Doesn't control anything. Purely for the flash messaging
    def emails_send_to
      [email, cc.presence].compact.to_sentence
    end

    def send_order_receipts!
      send_order_receipt_to_admin! if EffectiveOrders.mailer[:send_order_receipt_to_admin]
      send_order_receipt_to_buyer! if EffectiveOrders.mailer[:send_order_receipt_to_buyer]
      send_refund_notification! if refund?
    end

    def send_order_receipt_to_admin!
      send_email(:order_receipt_to_admin, to_param) if purchased?
    end

    def send_order_receipt_to_buyer!
      send_email(:order_receipt_to_buyer, to_param) if purchased?
    end

    def send_payment_request_to_buyer!
      send_email(:payment_request_to_buyer, to_param) unless purchased?
    end

    def send_pending_order_invoice_to_buyer!
      send_email(:pending_order_invoice_to_buyer, to_param) unless purchased?
    end

    def send_refund_notification!
      send_email(:refund_notification_to_admin, to_param) if purchased? && refund?
    end

    def skip_qb_sync!
      EffectiveOrders.use_effective_qb_sync ? EffectiveQbSync.skip_order!(self) : true
    end

    protected

    def get_tax_rate
      rate = instance_exec(self, &EffectiveOrders.order_tax_rate_method).to_f

      if (rate > 100.0 || (rate < 0.25 && rate > 0.0000))
        raise "expected EffectiveOrders.order_tax_rate_method to return a value between 100.0 (100%) and 0.25 (0.25%) or 0 or nil. Received #{rate}. Please return 5.25 for 5.25% tax."
      end

      rate
    end

    def get_tax
      return nil unless tax_rate.present?
      present_order_items.reject { |oi| oi.tax_exempt? }.map { |oi| (oi.subtotal * (tax_rate / 100.0)).round(0).to_i }.sum
    end

    private

    def present_order_items
      order_items.reject { |oi| oi.marked_for_destruction? }
    end

    def assign_order_totals
      self.subtotal = present_order_items.map { |oi| oi.subtotal }.sum
      self.tax_rate = get_tax_rate() unless (tax_rate || 0) > 0
      self.tax = get_tax()
      self.total = subtotal + (tax || 0)
    end

    def assign_billing_name
      self.billing_name = [(billing_address.full_name.presence if billing_address.present?), (user.to_s.presence)].compact.first
    end

    def assign_email
      self.email = user&.email
    end

    def assign_last_address
      return unless user.present?
      return unless (EffectiveOrders.billing_address || EffectiveOrders.shipping_address)
      return if EffectiveOrders.billing_address && billing_address.present?
      return if EffectiveOrders.shipping_address && shipping_address.present?

      last_order = Effective::Order.sorted.where(user: user).last
      return unless last_order.present?

      if EffectiveOrders.billing_address && last_order.billing_address.present?
        self.billing_address = last_order.billing_address
      end

      if EffectiveOrders.shipping_address && last_order.shipping_address.present?
        self.shipping_address = last_order.shipping_address
      end
    end

    def update_purchasables_purchased_order!
      order_items.each { |oi| oi.purchasable&.update_column(:purchased_order_id, self.id) }
    end

    def run_purchasable_callbacks(name)
      order_items.each { |oi| oi.purchasable.public_send(name, self, oi) if oi.purchasable.respond_to?(name) }
    end

    def send_email(email, *args)
      raise('expected args to be an Array') unless args.kind_of?(Array)

      if defined?(Tenant)
        tenant = Tenant.current || raise('expected a current tenant')
        args << { tenant: tenant }
      end

      deliver_method = EffectiveOrders.mailer[:deliver_method] || EffectiveResources.deliver_method

      begin
        EffectiveOrders.mailer_klass.send(email, *args).send(deliver_method)
      rescue => e
        raise if Rails.env.development? || Rails.env.test?
      end
    end

    def payment_to_h(payment)
      if payment.respond_to?(:to_unsafe_h)
        payment.to_unsafe_h.to_h
      elsif payment.respond_to?(:to_h)
        payment.to_h
      else
        { details: (payment.to_s.presence || 'none') }
      end
    end

  end
end
