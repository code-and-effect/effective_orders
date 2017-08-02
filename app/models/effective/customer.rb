module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :token # This is a convenience method so we have a place to store StripeConnect temporary access tokens

    belongs_to :user
    has_many :subscriptions, class_name: 'Effective::Subscription', foreign_key: 'customer_id'
    has_many :subscribables, through: :subscriptions, source: :subscribable

    accepts_nested_attributes_for :subscriptions

    # Attributes
    # stripe_customer_id            :string  # cus_xja7acoa03
    # stripe_active_card            :string  # **** **** **** 4242 Visa 05/12
    # stripe_subscription_id        :string  # Each user gets one stripe subscription object, which can contain many items
    # stripe_connect_access_token   :string  # If using StripeConnect and this user is a connected Seller
    #
    # timestamps



    before_validation(if: -> { stripe_customer_id.blank? && user && user.email.present? }) { stripe_customer }

    validates :user, presence: true
    validates :stripe_customer_id, presence: true

    before_save do
      if subscriptions.any? { |sub| sub.changed? }
      end
    end

    def self.for_user(user)
      Effective::Customer.where(user: user).first_or_initialize
    end

    def to_s
      user.to_s.presence || 'New Customer'
    end

    def stripe_customer
      @stripe_customer ||= if stripe_customer_id.present?
        ::Stripe::Customer.retrieve(stripe_customer_id)
      else
        Rails.logger.info "STRIPE CUSTOMER CREATE: #{user.email} and #{user.id}"
        ::Stripe::Customer.create(email: user.email, description: "User #{user.id}").tap do |stripe_customer|
          self.stripe_customer_id = stripe_customer.id
        end
      end
    end

    def stripe_subscription
      @stripe_subscription ||= if stripe_subscription_id.present?
        stripe_customer.subscriptions.retrieve(stripe_subscription_id)
      else
        Rails.logger.info "STRIPE SUBSCRIPTION CREATE: #{stripe_customer_id}"

        ::Stripe::Customer.create(customer: stripe_customer_id).tap do |stripe_subscription_id|
          self.stripe_subscription_id = stripe_subscription_id.id
        end
      end
    end

    def update_card!(token)
      if token.present? # Oh, so they want to use a new credit card...
        if stripe_customer.respond_to?(:cards)
          stripe_customer.card = token  # This sets the default_card to the new card
        elsif stripe_customer.respond_to?(:sources)
          stripe_customer.source = token
        else
          raise 'unknown stripe card/source token method'
        end

        if stripe_customer.save && default_card.present?
          card = cards.retrieve(default_card)

          self.stripe_active_card = "**** **** **** #{card.last4} #{card.brand} #{card.exp_month}/#{card.exp_year}"
          save!
        else
          raise 'unable to update stripe customer with new card'
        end
      end
    end

    def is_stripe_connect_seller?
      stripe_connect_access_token.present?
    end

    private

    def default_card
      if stripe_customer.respond_to?(:default_card)
        stripe_customer.default_card
      elsif stripe_customer.respond_to?(:default_source)
        stripe_customer.default_source
      else
        raise 'unknown stripe default card method'
      end
    end

    def cards
      if stripe_customer.respond_to?(:cards)
        stripe_customer.cards
      elsif stripe_customer.respond_to?(:sources)
        stripe_customer.sources
      else
        raise 'unknown stripe cards method'
      end
    end
  end
end
