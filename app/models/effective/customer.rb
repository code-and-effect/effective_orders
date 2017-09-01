module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :stripe_token # This is a convenience method so we have a place to store StripeConnect temporary access tokens
    attr_accessor :stripe_customer, :stripe_subscription

    belongs_to :user
    has_many :subscriptions, class_name: 'Effective::Subscription', foreign_key: 'customer_id'
    has_many :subscribables, through: :subscriptions, source: :subscribable

    accepts_nested_attributes_for :subscriptions

    # Attributes
    # stripe_customer_id            :string  # cus_xja7acoa03
    # active_card                   :string  # **** **** **** 4242 Visa 05/12

    # stripe_subscription_id        :string  # Each user gets one stripe subscription object, which can contain many items
    # status                        :string

    # stripe_connect_access_token   :string  # If using StripeConnect and this user is a connected Seller
    #
    # timestamps

    scope :deep, -> { includes(subscriptions: :subscribable) }

    before_validation do
      subscriptions.each { |subscription| subscription.status = status }
    end

    validates :user, presence: true
    validates :stripe_customer_id, presence: true
    validates :status, if: -> { stripe_subscription_id.present? }, inclusion: { in: %w(active past_due) }

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

    def assign_card!(token)
      return true unless token.present?

      stripe_customer.source = token

      Rails.logger.info "STRIPE CUSTOMER SOURCE UPDATE #{token}"

      if stripe_customer.save == false
        self.errors.add(:active_card, 'unable to update stripe active card')
        raise 'unable to update stripe active card'
      end

      # if unpaid. Pay the latest invoice immediately.....?

      if stripe_customer.default_source.present?
        card = stripe_customer.sources.retrieve(stripe_customer.default_source)
        self.active_card = "**** **** **** #{card.last4} #{card.brand} #{card.exp_month}/#{card.exp_year}"
      end

      true
    end

    def update_card!(token)
      assign_card!(token) && save!
    end

    def token_required?
      active_card.blank? || (active_card.present? && stripe_subscription_id.present? && status != 'active')
    end

    def payment_status
      if status == 'past_due'
        'We ran into an error processing your last payment. Please update or confirm your card details to continue.'
      elsif active_card.present? && token_required?
        'Please update or comfirm your card details to continue.'
      elsif active_card.present?
        'Thank You for your support! The card we have on file is'
      else
        'No credit card on file. Please add a card.'
      end.html_safe
    end

  end
end
