module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :stripe_customer, :stripe_subscription

    belongs_to :user
    has_many :subscribables, as: :subscribable

    has_many :subscriptions, class_name: 'Effective::Subscription', foreign_key: 'customer_id'
    has_many :subscribables, through: :subscriptions, source: :subscribable

    #accepts_nested_attributes_for :subscriptions

    # Attributes
    # stripe_customer_id            :string  # cus_xja7acoa03
    # active_card                   :string  # **** **** **** 4242 Visa 05/12

    # stripe_subscription_id        :string  # Each user gets one stripe subscription object, which can contain many items
    # status                        :string

    # timestamps

    scope :deep, -> { includes(subscriptions: :subscribable) }

    before_validation do
      subscriptions.each { |subscription| subscription.status = status }
    end

    validates :user, presence: true
    validates :stripe_customer_id, presence: true
    validates :status, if: -> { stripe_subscription_id.present? }, inclusion: { in: EffectiveOrders::STATUSES.keys }

    def self.for_user(user)
      Effective::Customer.where(user: user).first_or_initialize
    end

    def to_s
      user.to_s.presence || 'New Customer'
    end

    def stripe_customer
      @stripe_customer ||= if stripe_customer_id.present?
        Rails.logger.info "STRIPE CUSTOMER RETRIEVE: #{stripe_customer_id}"
        ::Stripe::Customer.retrieve(stripe_customer_id)
      end
    end

    def stripe_subscription
      @stripe_subscription ||= if stripe_subscription_id.present?
        Rails.logger.info "STRIPE SUBSCRIPTION RETRIEVE: #{stripe_subscription_id}"
        ::Stripe::Subscription.retrieve(stripe_subscription_id)
      end
    end

    def upcoming_invoice
      @upcoming_invoice ||= if stripe_customer_id.present? && stripe_subscription_id.present?
        Rails.logger.info "STRIPE UPCOMING INVOICE RETRIEVE: #{stripe_customer_id}"
        ::Stripe::Invoice.upcoming(customer: stripe_customer_id) rescue nil
      end
    end

    def token_required?
      active_card.blank? || (active_card.present? && stripe_subscription_id.present? && status != 'active')
    end

    def payment_status
      if status == 'past_due'
        'We ran into an error processing your last payment. Please update or confirm your card details to continue.'
      elsif active_card.present? && token_required?
        'Please update or confirm your card details to continue.'
      elsif active_card.present?
        'Thanks for your support! The card we have on file is'
      else
        'No credit card on file. Please add a card.'
      end.html_safe
    end

  end
end
