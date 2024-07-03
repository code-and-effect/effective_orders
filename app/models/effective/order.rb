# When an Order is first initialized it is done in the pending status
# - when it's in the pending status, none of the buyer entered information is required
# - when a pending order is rendered:
# - if the user has a billing address, go to step 2
# - if the user has no billing address, go to step 1
#
# After Step1, we go to the confirmed status
# After Step2, we are in the purchased or declined status

module Effective
  class Order < ActiveRecord::Base
    self.table_name = (EffectiveOrders.orders_table_name || :orders).to_s

    # Effective Resources
    acts_as_statused(
      :pending,         # New orders are created in a pending state
      :confirmed,       # Once the order has passed checkout step 1
      :deferred,        # Deferred providers. cheque, etransfer, phone or deluxe_delayed was selected.
      :purchased,       # Purchased by provider
      :declined,        # Declined by provider
      :voided,          # Voided by admin
      :abandoned        # Not set by this gem. Can be set outside it.
    )

    # Effective Addresses
    acts_as_addressable(billing: { singular: true }, shipping: { singular: true })

    # Effective Logging
    log_changes if respond_to?(:log_changes)

    # Effective Obfuscation
    if EffectiveOrders.obfuscate_order_ids
      raise('unsupported obfuscation with tenant') if defined?(Tenant)
      acts_as_obfuscated format: '###-####-###'
    end

    # Effective Reports
    acts_as_reportable if respond_to?(:acts_as_reportable)

    attr_accessor :terms_and_conditions # Yes, I agree to the terms and conditions
    attr_accessor :confirmed_checkout   # Set on the Checkout Step 1

    # Settings in the /admin action forms
    attr_accessor :send_payment_request_to_buyer # Set by Admin::Orders#new. Should the payment request email be sent after creating an order?
    attr_accessor :send_mark_as_paid_email_to_buyer  # Set by Admin::Orders#mark_as_paid
    attr_accessor :skip_buyer_validations # Set by Admin::Orders#create

    # If we want to use orders in a has_many way
    belongs_to :parent, polymorphic: true, optional: true

    # This is user the order is for
    belongs_to :user, polymorphic: true, optional: true, validate: false
    accepts_nested_attributes_for :user, allow_destroy: false, update_only: true

    # When an organization is present, any user with role :billing in that organization can purchase this order
    belongs_to :organization, polymorphic: true, optional: true, validate: false
    accepts_nested_attributes_for :organization, allow_destroy: false, update_only: true

    # When purchased, this is the user that purchased it.
    belongs_to :purchased_by, polymorphic: true, optional: true, validate: false

    has_many :order_items, -> { order(:id) }, inverse_of: :order, dependent: :delete_all
    accepts_nested_attributes_for :order_items, allow_destroy: true, reject_if: :all_blank

    # Attributes
    effective_resource do
      # Acts as Statused
      status            :string
      status_steps      :text

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

      tax_rate            :decimal, precision: 6, scale: 3
      surcharge_percent   :decimal, precision: 6, scale: 3

      subtotal          :integer   # Sum of items subtotal
      tax               :integer   # Tax on subtotal
      amount_owing      :integer   # Subtotal + Tax

      surcharge         :integer   # Credit Card Surcharge
      surcharge_tax     :integer   # Tax on surcharge

      total             :integer   # Subtotal + Tax + Surcharge + Surcharge Tax

      # For use with the Deluxe Delayed Payment feature

      # When an order is created. These two attributes can be set to create a delayed? order
      delayed_payment         :boolean
      delayed_payment_date    :date

      # When the order goes to checkout we require the delayed_payment_intent and total
      # This stores the user's card information
      # This is required for the order to become deferred?
      delayed_payment_intent  :text
      delayed_payment_total   :integer  # Only for reference, not really used. This is the order total we showed them when they last save card info'd

      # Set by the rake task that runs 1/day and processes any delayed orders before or on that day
      delayed_payment_purchase_ran_at   :datetime
      delayed_payment_purchase_result   :text

      timestamps
    end

    if EffectiveResources.serialize_with_coder?
      serialize :payment, type: Hash, coder: YAML
    else
      serialize :payment, Hash
    end

    scope :deep, -> { 
      includes(:addresses, :user, :parent, :purchased_by, :organization, order_items: :purchasable) 
    }

    scope :for, -> (user) {
      if user.respond_to?(:organizations)
        where(user: user).or(where(organization: user.organizations))
      else
        where(user: user)
      end
    }

    scope :sorted, -> { order(:id) }

    scope :purchased, -> { where(status: :purchased) }
    scope :purchased_or_deferred, -> { where(status: [:purchased, :deferred]) }

    scope :purchased_by, lambda { |user| purchased.where(user: user) }

    scope :not_purchased, -> { where.not(status: [:purchased, :deferred]) }
    scope :was_not_purchased, -> { where.not(status: :purchased) }

    scope :pending, -> { where(status: :pending) }
    scope :confirmed, -> { where(status: :confirmed) }
    scope :deferred, -> { where(status: :deferred) }
    scope :declined, -> { where(status: :declined) }
    scope :abandoned, -> { where(status: :abandoned) }
    scope :voided, -> { where(status: :voided) }

    scope :refunds, -> { purchased.where('total < ?', 0) }
    scope :pending_refunds, -> { not_purchased.where('total < ?', 0) }

    scope :delayed, -> { where(delayed_payment: true).where.not(delayed_payment_date: nil) }
    scope :delayed_payment_date_past, -> { delayed.where(arel_table[:delayed_payment_date].lteq(Time.zone.today)) }
    scope :delayed_payment_date_upcoming, -> { delayed.where(arel_table[:delayed_payment_date].gt(Time.zone.today)) }

    # Used by the rake effective_orders:purchase_delayed_orders task
    scope :delayed_ready_to_purchase, -> { 
      delayed.deferred.delayed_payment_date_past.where(delayed_payment_purchase_ran_at: nil)
    }

    # effective_reports
    def reportable_scopes
      { purchased: nil, not_purchased: nil, deferred: nil, refunds: nil, pending_refunds: nil }
    end

    before_validation do
      assign_attributes(status: :confirmed) if pending? && confirmed_checkout
    end

    before_validation do
      assign_attributes(user_type: nil) if user_type.present? && user_id.blank?
      assign_attributes(organization_type: nil) if organization_type.present? && organization_id.blank?
    end

    with_options(unless: -> { done? }) do
      before_validation { assign_organization_address }
      before_validation { assign_user_address }
      before_validation { assign_billing_name }
      before_validation { assign_billing_email }
      before_validation { assign_order_item_values }
      before_validation { assign_order_values }
      before_validation { assign_order_charges }
    end

    # Order validations
    validates :email, presence: true, email: true, if: -> { user_id.present? }  # email and cc validators are from effective_resources
    validates :cc, email_cc: true

    validates :order_items, presence: { message: 'No items are present. Please add additional items.' }

    # Delayed Payment Validations
    validates :delayed_payment_date, presence: true, if: -> { delayed_payment? }
    validates :delayed_payment_date, absence: true, unless: -> { delayed_payment? }

    with_options(if: -> { delayed? && deferred? }) do
      validates :delayed_payment_intent, presence: { message: 'please provide your card information' }
      validates :delayed_payment_total, presence: true
    end

    validate do
      if EffectiveOrders.organization_enabled?
        errors.add(:base, "must have a User or #{EffectiveOrders.organization_class_name || 'Organization'}") if user_id.blank? && organization_id.blank?
      else
        errors.add(:base, "must have a User") if user_id.blank?
      end
    end

    # Price validations
    validates :subtotal, presence: true
    validates :total, presence: true, if: -> { EffectiveOrders.minimum_charge.to_i > 0 }

    validate(if: -> { total.present? && EffectiveOrders.minimum_charge.to_i > 0 }, unless: -> { purchased? || (free? && EffectiveOrders.free?) || (refund? && EffectiveOrders.refund?) }) do
      if total < EffectiveOrders.minimum_charge
        errors.add(:total, "must be $#{'%0.2f' % (EffectiveOrders.minimum_charge.to_i / 100.0)} or more. Please add additional items.")
      end
    end

    validate(if: -> { tax_rate.present? }) do
      if (tax_rate > 100.0 || (tax_rate < 0.25 && tax_rate > 0.0000))
        errors.add(:tax_rate, "is invalid. expected a value between 100.0 (100%) and 0.25 (0.25%) or 0")
      end
    end

    # User validations -- An admin skips these when working in the admin/ namespace
    with_options(unless: -> { pending? || skip_buyer_validations? || purchased? }) do
      validates :tax_rate, presence: { message: "can't be determined based on billing address" }
      validates :tax, presence: true

      validates :billing_address, presence: true, if: -> { EffectiveOrders.billing_address }
      validates :shipping_address, presence: true, if: -> { EffectiveOrders.shipping_address }
      validates :note, presence: true, if: -> { EffectiveOrders.collect_note_required }
    end

    # When Purchased
    with_options(if: -> { purchased? }) do
      validates :purchased_at, presence: true
      validates :payment, presence: true

      validates :payment_provider, presence: true
      validates :payment_card, presence: true
    end

    with_options(if: -> { deferred? }) do
      validates :payment_provider, presence: true

      validate do
        unless EffectiveOrders.deferred_providers.include?(payment_provider) || EffectiveOrders.delayed_providers.include?(payment_provider)
          errors.add(:payment_provider, "unknown deferred payment provider") 
        end
      end
    end

    validate(if: -> { was_voided? && status_changed? }) do
      errors.add(:status, "cannot update status of a voided order") unless voided?
    end

    # Sanity check
    before_save(if: -> { status_was.to_s == 'purchased' }) do
      raise('cannot unpurchase an order. try voiding instead.') unless purchased? || voided?

      raise('cannot change subtotal of a purchased order') if changes[:subtotal].present?

      raise('cannot change tax of a purchased order') if changes[:tax].present?
      raise('cannot change tax rate of a purchased order') if changes[:tax_rate].present?

      raise('cannot change surcharge of a purchased order') if changes[:surcharge].present?
      raise('cannot change surcharge percent of a purchased order') if changes[:surcharge_percent].present?

      raise('cannot change total of a purchased order') if changes[:total].present?
    end

    # Effective::Order.new()
    # Effective::Order.new(Product.first)
    # Effective::Order.new(current_cart)
    # Effective::Order.new(Effective::Order.last)

    # Effective::Order.new(items: Product.first)
    # Effective::Order.new(items: [Product.first, Product.second], user: User.first)
    # Effective::Order.new(items: Product.first, user: User.first, billing_address: Effective::Address.new, shipping_address: Effective::Address.new)

    def initialize(atts = nil, &block)
      super(status: :pending) # Initialize with status pending

      return self unless atts.present?

      if atts.kind_of?(Hash)
        items = Array(atts[:item]) + Array(atts[:items])

        self.user = atts[:user] || items.first.try(:user)

        if (address = atts[:billing_address]).present?
          self.billing_address = address
          self.billing_address.full_name ||= user.to_s.presence
        end

        if (address = atts[:shipping_address]).present?
          self.shipping_address = address
          self.shipping_address.full_name ||= user.to_s.presence
        end

        atts.except(:item, :items, :user, :billing_address, :shipping_address).each do |key, value|
          self.send("#{key}=", value)
        end

        add(items) if items.present?
      else # Attributes are not a Hash
        self.user = atts.user if atts.respond_to?(:user)
        add(atts)
      end

      self
    end

    def remove(*items)
      raise 'unable to alter a purchased order' if purchased?
      raise 'unable to alter a declined order' if declined?

      removed = items.map do |item|
        order_item = if item.kind_of?(Effective::OrderItem)
          order_items.find { |oi| oi == item }
        else
          order_items.find { |oi| oi.purchasable == item }
        end

        raise("Unable to find order item for #{item}") if order_item.blank?
        order_item
      end

      removed.each { |order_item| order_item.mark_for_destruction }

      # Make sure to reset stored aggregates
      assign_attributes(subtotal: nil, tax_rate: nil, tax: nil, amount_owing: nil, surcharge_percent: nil, surcharge: nil, total: nil)

      removed.length == 1 ? removed.first : removed
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
          self.cc ||= item.cc

          item.order_items.select { |oi| oi.purchasable.kind_of?(Effective::Product) }.map do |oi|
            purchasable = oi.purchasable

            product = Effective::Product.new(name: purchasable.purchasable_name, price: purchasable.price, tax_exempt: purchasable.tax_exempt)

            # Copy over any extended attributes that may have been created
            atts = purchasable.dup.attributes.except('name', 'price', 'tax_exempt', 'purchased_order_id').compact

            atts.each do |k, v|
              next unless product.respond_to?("#{k}=") && product.respond_to?(k)
              product.send("#{k}=", v) if product.send(k).blank?
            end

            Effective::CartItem.new(quantity: oi.quantity, purchasable: product)
          end
        else
          raise 'add() expects one or more acts_as_purchasable objects, or an Effective::Cart'
        end
      end.compact

      # Make sure to reset stored aggregates
      assign_attributes(subtotal: nil, tax_rate: nil, tax: nil, amount_owing: nil, surcharge_percent: nil, surcharge: nil, total: nil)

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

      present_order_items.each do |item|
        purchasable = item.purchasable

        if purchasable.blank? || purchasable.marked_for_destruction?
          item.mark_for_destruction
        else
          item.assign_purchasable_attributes
        end
      end

      save!
    end

    def to_s
      [label, ' #', to_param].join
    end

    def label
      if refund? && purchased?
        'Refund'
      elsif purchased?
        'Receipt'
      elsif refund? && (pending? || confirmed?)
        'Pending Refund'
      elsif (pending? || confirmed?)
        'Pending Order'
      else
        'Order'
      end
    end

    def total_label
      purchased? ? 'Total Paid' : 'Total Due'
    end

    def payment_method
      payment_method_value if purchased?
    end

    def delayed_payment_method
      payment_method_value if delayed?
    end

    def duplicate
      Effective::Order.new(self)
    end

    # For moneris and moneris_checkout. Just a unique value. Must be 50 characters or fewer or will raise moneris error.
    def transaction_id
      [to_param, billing_name.to_s.parameterize.first(20).presence, Time.zone.now.to_i, rand(1000..9999)].compact.join('-')
    end

    def billing_first_name
      billing_name.to_s.split(' ').first
    end

    def billing_last_name
      Array(billing_name.to_s.split(' ')[1..-1]).join(' ')
    end

    def in_progress?
      pending? || confirmed? || deferred?
    end

    def done?
      persisted? && (purchased? || declined? || voided? || abandoned?)
    end

    # A custom order is one that was created by an admin
    # We allow custom orders to have their order items updated
    def custom_order?
      order_items.all? { |oi| oi.purchasable_type == 'Effective::Product' }
    end

    def purchased?(provider = nil)
      return false if (status.to_sym != :purchased)
      return true if provider.nil? || payment_provider == provider.to_s
      false
    end

    def purchased_with_credit_card?
      purchased? && EffectiveOrders.credit_card_payment_providers.include?(payment_provider)
    end

    def purchased_without_credit_card?
      purchased? && EffectiveOrders.credit_card_payment_providers.exclude?(payment_provider)
    end

    def purchasables
      present_order_items.map { |order_item| order_item.purchasable }.compact
    end

    def subtotal
      self[:subtotal] || get_subtotal()
    end

    def tax_rate
      self[:tax_rate] || get_tax_rate()
    end

    def tax
      self[:tax] || get_tax()
    end

    def amount_owing
      self[:amount_owing] || get_amount_owing()
    end

    def surcharge_percent
      self[:surcharge_percent] || get_surcharge_percent()
    end

    def surcharge
      self[:surcharge] || get_surcharge()
    end

    def surcharge_tax
      self[:surcharge_tax] || get_surcharge_tax()
    end

    def total
      self[:total] || get_total()
    end

    def total_to_f
      ((total || 0) / 100.0).to_f
    end

    def total_with_surcharge
      get_total_with_surcharge()
    end

    def total_without_surcharge
      get_total_without_surcharge()
    end

    def payment
      Hash(self[:payment])
    end

    def free?
      total == 0
    end

    def refund?
      total.to_i < 0
    end
    
    # A new order is created.
    # If the delayed_payment and delayed_payment date are set, it's a delayed order
    # A delayed order is one in which we have to capture a payment intent for the amount of the order.
    # Once it's delayed and deferred we can purchase it at anytime.
    def delayed?
      delayed_payment? && delayed_payment_date.present?
    end

    def delayed_ready_to_purchase?
      return false unless delayed? 
      return false unless deferred?
      return false unless delayed_payment_intent.present?
      return false if delayed_payment_date_upcoming?
      return false if delayed_payment_purchase_ran_at.present? # We ran before and probably failed

      true
    end

    def delayed_payment_info
      return unless delayed? && deferred?
      return unless delayed_payment_date_upcoming?

      "Your #{delayed_payment_method} will be charged $#{'%0.2f' % total_to_f} on #{delayed_payment_date.strftime('%F')}"
    end

    def delayed_payment_date_upcoming?
      return false unless delayed?
      delayed_payment_date > Time.zone.now.to_date
    end

    def delayed_payment_date_today?
      return false unless delayed?
      delayed_payment_date == Time.zone.now.to_date
    end

    def delayed_payment_date_past?
      return false unless delayed?
      delayed_payment_date < Time.zone.now.to_date
    end

    def pending_refund?
      return false if EffectiveOrders.buyer_purchases_refund?
      return false if purchased?

      refund?
    end

    def num_items
      present_order_items.map { |oi| oi.quantity }.sum
    end

    def send_order_receipt_to_admin?
      return false if free? && !EffectiveOrders.send_order_receipts_when_free
      EffectiveOrders.send_order_receipt_to_admin
    end

    def send_order_receipt_to_buyer?
      return false if free? && !EffectiveOrders.send_order_receipts_when_free
      EffectiveOrders.send_order_receipt_to_buyer
    end

    def send_order_declined_to_admin?
      return false if free? && !EffectiveOrders.send_order_receipts_when_free
      EffectiveOrders.send_order_declined_to_admin
    end

    def send_order_declined_to_buyer?
      return false if free? && !EffectiveOrders.send_order_receipts_when_free
      EffectiveOrders.send_order_declined_to_buyer
    end

    def send_payment_request_to_buyer?
      return false if free? && !EffectiveOrders.send_order_receipts_when_free
      return false if refund?

      EffectiveResources.truthy?(send_payment_request_to_buyer)
    end

    def send_refund_notification_to_admin?
      return false unless refund?
      EffectiveOrders.send_refund_notification_to_admin
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

      assign_attributes(status: :pending)
      self.addresses.clear if addresses.any? { |address| address.valid? == false }
      save!

      if send_payment_request_to_buyer?
        after_commit { send_payment_request_to_buyer! }
      end

      true
    end

    # Used by admin checkout only
    def confirm!
      return false if purchased?
      confirmed!
    end

    # This lets us skip to the confirmed workflow for an admin...
    def assign_confirmed_if_valid!
      return unless pending?

      assign_attributes(status: :confirmed)
      return true if valid?

      self.errors.clear
      assign_attributes(status: :pending)
      false
    end

    # Called by effective_memberships to update prices from purchasable fees
    # Not called internally
    def update_purchasable_attributes
      present_order_items.each { |oi| oi.update_purchasable_attributes }
    end

    def update_purchasable_attributes!
      raise('cannot update purchasable attributes of a purchased order') if purchased?
      update_purchasable_attributes
      save!
    end

    # Call this as a way to skip over non consequential orders
    # And mark some purchasables purchased
    # This is different than the Mark as Paid payment processor
    def mark_as_purchased!(current_user: nil)
      purchase!(skip_buyer_validations: true, email: false, skip_quickbooks: true, current_user: current_user)
    end

    # Effective::Order.new(items: Product.first, user: User.first).purchase!(email: false)
    def purchase!(payment: nil, provider: nil, card: nil, email: true, skip_buyer_validations: false, skip_quickbooks: false, current_user: nil)
      return true if purchased?

      raise('unable to purchase voided order') if voided?

      # Assign attributes
      assign_attributes(
        skip_buyer_validations: skip_buyer_validations,

        status: :purchased,
        purchased_at: (purchased_at.presence || Time.zone.now),
        purchased_by: (purchased_by.presence || current_user),

        payment: payment_to_h(payment.presence || 'none'),
        payment_provider: (provider.presence || 'none'),
        payment_card: (card.presence || 'none'),

        delayed_payment_intent: nil # Do not store the delayed payment intent any longer
      )

      if current_user&.email.present?
        assign_attributes(email: current_user.email)
      end

      # Updates surcharge and total based on payment_provider
      assign_order_charges()

      begin
        Effective::Order.transaction do
          run_purchasable_callbacks(:before_purchase)

          save!
          update_purchasables_purchased_order!

          run_purchasable_callbacks(:after_purchase)
        end
      rescue ActiveRecord::RecordInvalid => e
        Effective::Order.transaction do
          save!(validate: false)
          update_purchasables_purchased_order!
        end

        raise(e)
      end

      send_order_receipts! if email
      after_commit { sync_quickbooks!(skip: skip_quickbooks) }

      true
    end

    # We support two different Quickbooks synchronization gems: effective_qb_sync and effective_qb_online
    def sync_quickbooks!(skip:)
      if EffectiveOrders.qb_online?
        skip ? EffectiveQbOnline.skip_order!(self) : EffectiveQbOnline.sync_order!(self)
      end

      if EffectiveOrders.qb_sync?
        skip ? EffectiveQbSync.skip_order!(self) : true # Nothing to do
      end

      true
    end

    def skip_quickbooks!
      sync_quickbooks!(skip: true)
    end

    # This was submitted via the deluxe_delayed provider checkout
    # This is a special case of a deferred provider. We require the payment_intent and payment info
    def delay!(payment:, payment_intent:, provider:, card:, email: false, validate: true)
      raise('expected payment intent to be a String') unless payment_intent.kind_of?(String)
      raise('expected a delayed payment provider') unless EffectiveOrders.delayed_providers.include?(provider)
      raise('expected a delayed payment order with a delayed_payment_date') unless delayed_payment? && delayed_payment_date.present?

      assign_attributes(
        delayed_payment_intent: payment_intent, 
        delayed_payment_total: total(),

        payment: payment_to_h(payment),
        payment_card: (card.presence || 'none')
      )

      defer!(provider: provider, email: email, validate: validate)
    end

    def defer!(provider: 'none', email: true, validate: true)
      raise('order already purchased') if purchased?

      # Assign attributes
      assign_attributes(
        payment_provider: provider,

        status: :deferred,
        purchased_at: nil,
        purchased_by: nil,

        deferred_at: (deferred_at.presence || Time.zone.now),
        deferred_by: (deferred_by.presence || current_user)
      )

      if current_user&.email.present?
        assign_attributes(email: current_user.email)
      end

      error = nil

      begin
        Effective::Order.transaction do
          run_purchasable_callbacks(:before_defer)
          save!(validate: validate)
          run_purchasable_callbacks(:after_defer)
        end
      rescue ActiveRecord::RecordInvalid => e
        self.status = status_was
        error = e.message
      end

      raise "Failed to defer order: #{error || errors.full_messages.to_sentence}" unless error.nil?

      send_payment_request_to_buyer! if email

      true
    end

    # We only turn on the email when done by a delayed payment or from a rake script.
    def decline!(payment: 'none', provider: 'none', card: 'none', validate: true, email: false)
      return false if declined?
      raise('order already purchased') if purchased?

      assign_attributes(
        skip_buyer_validations: true,

        status: :declined,
        purchased_at: nil,
        purchased_by: nil,

        payment: payment_to_h(payment),
        payment_provider: provider,
        payment_card: (card.presence || 'none')
      )

      if current_user&.email.present?
        assign_attributes(email: current_user.email)
      end

      error = nil

      Effective::Order.transaction do
        begin
          run_purchasable_callbacks(:before_decline)
          save!(validate: validate)
          run_purchasable_callbacks(:after_decline)
        rescue ActiveRecord::RecordInvalid => e
          self.status = status_was
          error = e.message
        end
      end

      raise "Failed to decline order: #{error || errors.full_messages.to_sentence}" unless error.nil?

      send_declined_notifications! if email

      true
    end

    def declined_reason
      return unless declined?

      delayed_payment_purchase_result.presence || 'credit card declined'
    end

    def void!
      raise('already voided') if voided?
      voided!(skip_buyer_validations: true)
    end

    def unvoid!
      raise('order must be voided to unvoid') unless voided?
      unvoided!(skip_buyer_validations: true)
    end

    def deluxe_delayed_purchase!
      raise('expected a delayed order') unless delayed?
      raise('expected a deferred order') unless deferred?
      raise('expected delayed payment intent') unless delayed_payment_intent.present?
      raise('expected a deluxe_delayed payment provider') unless payment_provider == 'deluxe_delayed'

      Effective::DeluxeApi.new().purchase_delayed_orders!(self)
    end

    # These are all the emails we send all notifications to
    def emails
      ([purchased_by.try(:email)] + [email] + [user.try(:email)] + Array(organization.try(:billing_emails))).map(&:presence).compact.uniq
    end

    # Doesn't control anything. Purely for the flash messaging
    def emails_send_to
      (emails + [cc.presence]).compact.uniq.to_sentence
    end

    def send_order_receipts!
      send_order_receipt_to_admin! if send_order_receipt_to_admin?
      send_order_receipt_to_buyer! if send_order_receipt_to_buyer?
      send_refund_notification! if send_refund_notification_to_admin?
    end

    def send_declined_notifications!
      send_order_declined_to_admin! if send_order_declined_to_admin?
      send_order_declined_to_buyer! if send_order_declined_to_buyer?
    end

    def send_order_declined_to_admin!
      EffectiveOrders.send_email(:order_declined_to_admin, self) if declined?
    end

    def send_order_declined_to_buyer!
      EffectiveOrders.send_email(:order_declined_to_buyer, self) if declined?
    end

    def send_order_receipt_to_admin!
      EffectiveOrders.send_email(:order_receipt_to_admin, self) if purchased?
    end

    def send_order_receipt_to_buyer!
      EffectiveOrders.send_email(:order_receipt_to_buyer, self) if purchased?
    end
    alias_method :send_buyer_receipt!, :send_order_receipt_to_buyer!

    def send_payment_request_to_buyer!
      EffectiveOrders.send_email(:payment_request_to_buyer, self) unless purchased?
    end

    def send_pending_order_invoice_to_buyer!
      EffectiveOrders.send_email(:pending_order_invoice_to_buyer, self) unless purchased?
    end

    def send_refund_notification!
      EffectiveOrders.send_email(:refund_notification_to_admin, self) if refund?
    end

    protected

    def get_subtotal
      present_order_items.map { |oi| oi.subtotal }.sum
    end

    def get_tax_rate
      rate = instance_exec(self, &EffectiveOrders.order_tax_rate_method).to_f

      if (rate > 100.0 || (rate < 0.25 && rate > 0.0000))
        raise "expected EffectiveOrders.order_tax_rate_method to return a value between 100.0 (100%) and 0.25 (0.25%) or 0 or nil. Received #{rate}. Please return 5.25 for 5.25% tax."
      end

      rate
    end

    def get_tax
      return 0 unless tax_rate.present?
      present_order_items.reject { |oi| oi.tax_exempt? }.map { |oi| (oi.subtotal * (tax_rate / 100.0)).round(0).to_i }.sum
    end

    def get_amount_owing
      subtotal + tax
    end

    def get_surcharge_percent
      percent = EffectiveOrders.credit_card_surcharge_percent.to_f
      return nil unless percent > 0.0

      return 0.0 if purchased_without_credit_card?

      if (percent > 10.0 || percent < 0.5)
        raise "expected EffectiveOrders.credit_card_surcharge to return a value between 10.0 (10%) and 0.5 (0.5%) or nil. Received #{percent}. Please return 2.5 for 2.5% surcharge."
      end

      percent
    end

    def get_surcharge
      return 0 unless surcharge_percent.present?
      ((subtotal + tax) * (surcharge_percent / 100.0)).round(0).to_i
    end

    def get_surcharge_tax
      return 0 unless tax_rate.present?
      (surcharge * (tax_rate / 100.0)).round(0).to_i
    end

    def get_total
      subtotal + tax + surcharge + surcharge_tax
    end

    def get_total_with_surcharge
      subtotal + tax + surcharge + surcharge_tax
    end

    def get_total_without_surcharge
      subtotal + tax
    end

    # Visa - 1234
    def payment_method_value
      provider = payment_provider if ['cheque', 'etransfer', 'phone', 'credit card'].include?(payment_provider)
      provider = 'credit card' if ['deluxe_delayed'].include?(payment_provider)

      # Normalize payment card
      card = case payment_card.to_s.downcase.gsub(' ', '').strip
        when '' then nil
        when 'v', 'visa' then 'Visa'
        when 'm', 'mc', 'master', 'mastercard' then 'MasterCard'
        when 'a', 'ax', 'american', 'americanexpress' then 'American Express'
        when 'd', 'discover' then 'Discover'
        else payment_card.to_s
      end

      # Try again
      if card == 'none' && payment['card_type'].present?
        card = case payment['card_type'].to_s.downcase.gsub(' ', '').strip
          when '' then nil
          when 'v', 'visa' then 'Visa'
          when 'm', 'mc', 'master', 'mastercard' then 'MasterCard'
          when 'a', 'ax', 'american', 'americanexpress' then 'American Express'
          when 'd', 'discover' then 'Discover'
          else payment_card.to_s
        end
      end

      last4 = if payment[:active_card] && payment[:active_card].include?('**** **** ****')
        payment[:active_card][15,4]
      end

      last4 ||= if payment['active_card'] && payment['active_card'].include?('**** **** ****')
        payment['active_card'][15,4]
      end

      # stripe, moneris, moneris_checkout
      last4 ||= (payment['f4l4'] || payment['first6last4']).to_s.last(4)

      [provider.presence, card.presence, last4.presence].compact.join(' - ')
    end

    private

    def present_order_items
      order_items.reject { |oi| oi.marked_for_destruction? }
    end

    # Organization first
    def assign_billing_name
      self.billing_name = billing_address.try(:full_name).presence || organization.to_s.presence || user.to_s.presence
    end

    # User first
    def assign_billing_email
      email = emails.first
      assign_attributes(email: email) if email.present?
    end

    def assign_organization_address
      return unless organization.present?

      if EffectiveOrders.billing_address && billing_address.blank? && organization.try(:billing_address).present?
        self.billing_address = organization.billing_address
        self.billing_address.full_name ||= organization.to_s.presence
      end

      if EffectiveOrders.shipping_address && shipping_address.blank? && organization.try(:shipping_address).present?
        self.shipping_address = organization.shipping_address
        self.shipping_address.full_name ||= organization.to_s.presence
      end
    end

    def assign_user_address
      return unless user.present?

      if EffectiveOrders.billing_address && billing_address.blank? && user.try(:billing_address).present?
        self.billing_address = user.billing_address
        self.billing_address.full_name ||= user.to_s.presence
      end

      if EffectiveOrders.shipping_address && shipping_address.blank? && user.try(:shipping_address).present?
        self.shipping_address = user.shipping_address
        self.shipping_address.full_name ||= user.to_s.presence
      end
    end

    # These two overwrites the prices, taxes, surcharge, etc on every save.
    # Does not get run from the before_validate on purchase.
    def assign_order_item_values
      # Copies prices from purchasable into order items
      present_order_items.each { |oi| oi.assign_purchasable_attributes }
    end

    def assign_order_values
      # Calculated from each item
      self.subtotal = get_subtotal()

      # We only know tax if there is a billing address
      self.tax_rate = get_tax_rate()
      self.tax = get_tax()

      # Subtotal + Tax
      self.amount_owing = get_amount_owing()
    end

    def assign_order_charges
      # We only apply surcharge for credit card orders. But we have to display and calculate for non purchased orders
      self.surcharge_percent = get_surcharge_percent()
      self.surcharge = get_surcharge()
      self.surcharge_tax = get_surcharge_tax()

      # Subtotal + Tax + Surcharge + Surcharge Tax
      self.total = get_total()
    end

    def update_purchasables_purchased_order!
      purchasables.each do |purchasable| 
        columns = {
          purchased_order_id: id,
          purchased_at: (purchased_at if purchasable.respond_to?(:purchased_at=)),
          purchased_by_id: (purchased_by_id if purchasable.respond_to?(:purchased_by_id=)),
          purchased_by_type: (purchased_by_type if purchasable.respond_to?(:purchased_by_type=))
        }.compact

        purchasable.update_columns(columns)
      end

      true
    end

    def run_purchasable_callbacks(name)
      order_items.select { |item| item.purchasable.respond_to?(name) }.each do |item|
        if item.class.respond_to?(:transaction)
          item.class.transaction { item.purchasable.public_send(name, self, item) }
        else
          item.purchasable.public_send(name, self, item)
        end
      end

      if parent.respond_to?(name)
        if parent.class.respond_to?(:transaction)
          parent.class.transaction { parent.public_send(name, self) }
        else
          parent.public_send(name, self)
        end
      end

      true
    end

    def payment_to_h(value)
      if value.respond_to?(:to_unsafe_h)
        value.to_unsafe_h.to_h
      elsif value.respond_to?(:to_h)
        value.to_h
      else
        { details: (value.to_s.presence || 'none') }
      end
    end

  end
end
