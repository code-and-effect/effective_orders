module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :stripe_customer

    belongs_to :user, polymorphic: true
    has_many :subscriptions, -> { includes(:subscribable) }, class_name: 'Effective::Subscription', foreign_key: 'customer_id'
    accepts_nested_attributes_for :subscriptions

    effective_resource do
      stripe_customer_id            :string  # cus_xja7acoa03
      payment_method_id             :string  # Last payment method used
      active_card                   :string  # **** **** **** 4242 Visa 05/12

      timestamps
    end

    scope :deep, -> { includes(subscriptions: :subscribable) }

    validates :user, presence: true
    validates :stripe_customer_id, presence: true

    def self.for_user(user)
      Effective::Customer.where(user: user).first_or_initialize
    end

    def to_s
      user.to_s.presence || 'New Customer'
    end

    def email
      user.email if user
    end

    def create_stripe_customer!
      return if stripe_customer.present?
      raise('expected a user') unless user.present?

      Rails.logger.info "[STRIPE] create customer: #{user.email}"

      self.stripe_customer = EffectiveOrders.with_stripe { ::Stripe::Customer.create(email: user.email, description: user.to_s, metadata: { user_id: user.id }) }
      self.stripe_customer_id = stripe_customer.id

      save!
    end

    def stripe_customer
      @stripe_customer ||= if stripe_customer_id.present?
        Rails.logger.info "[STRIPE] get customer: #{stripe_customer_id}"
        EffectiveOrders.with_stripe { ::Stripe::Customer.retrieve(stripe_customer_id) }
      end
    end

    def invoices
      @invoices ||= if stripe_customer_id.present?
        Rails.logger.info "[STRIPE] list invoices: #{stripe_customer_id}"
        EffectiveOrders.with_stripe { ::Stripe::Invoice.list(customer: stripe_customer_id) rescue nil }
      end
    end

    def upcoming_invoice
      @upcoming_invoice ||= if stripe_customer_id.present?
        Rails.logger.info "[STRIPE] get upcoming invoice: #{stripe_customer_id}"
        EffectiveOrders.with_stripe { ::Stripe::Invoice.upcoming(customer: stripe_customer_id) rescue nil }
      end
    end

    def token_required?
      active_card.blank? || past_due?
    end

    def past_due?
      subscriptions.any? { |subscription| subscription.past_due? }
    end

    def active?
      subscriptions.present? && subscriptions.all? { |subscription| subscription.active? }
    end

    def payment_status
      if past_due?
        'We ran into an error processing your last payment. Please update or confirm your card details to continue.'
      elsif active?
        "Your payment is in good standing. Thanks so much for your support!"
      elsif active_card.blank?
        'No credit card on file. Please add a card.'
      else
        'Please update or confirm your card details to continue.'
      end.html_safe
    end

  end
end
