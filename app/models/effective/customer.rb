module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :token # This is a convenience method so we have a place to store StripeConnect temporary access tokens
    attr_accessor :stripe_customer, :stripe_subscription

    belongs_to :user
    has_many :subscriptions, class_name: 'Effective::Subscription', foreign_key: 'customer_id'
    has_many :subscribables, through: :subscriptions, source: :subscribable

    accepts_nested_attributes_for :subscriptions

    # Attributes
    # stripe_customer_id            :string  # cus_xja7acoa03
    # active_card                   :string  # **** **** **** 4242 Visa 05/12

    # stripe_subscription_id        :string  # Each user gets one stripe subscription object, which can contain many items
    # current_period_end            :datetime
    # status                        :string

    # stripe_connect_access_token   :string  # If using StripeConnect and this user is a connected Seller
    #
    # timestamps

    scope :deep, -> { includes(subscriptions: :subscribable) }

    validates :user, presence: true
    validates :stripe_customer_id, presence: true

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

    def assign_card!(token)
      return true unless token.present?

      stripe_customer.source = token

      Rails.logger.info "STRIPE CUSTOMER SOURCE UPDATE #{token}"
      if stripe_customer.save == false
        self.errors.add(:active_card, 'unable to update stripe active card')
        raise 'unable to update stripe active card'
      end

      if stripe_customer.default_source.present?
        card = stripe_customer.sources.retrieve(stripe_customer.default_source)
        self.active_card = "**** **** **** #{card.last4} #{card.brand} #{card.exp_month}/#{card.exp_year}"
      end

      true
    end

    def update_card!(token)
      assign_card!(token) && save!
    end

  end
end
