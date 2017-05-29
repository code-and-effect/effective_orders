module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :token # This is a convenience method so we have a place to store StripeConnect temporary access tokens

    belongs_to :user
    has_many :subscriptions, inverse_of: :customer, class_name: 'Effective::Subscription'

    # Attributes
    # stripe_customer_id            :string  # cus_xja7acoa03
    # stripe_active_card            :string  # **** **** **** 4242 Visa 05/12
    # stripe_connect_access_token   :string  # If using StripeConnect and this user is a connected Seller
    #
    # timestamps

    validates :user, presence: true
    validates :user_id, uniqueness: true

    scope :customers, -> { where.not(stripe_customer_id: nil) }

    def self.for_user(user)
      Effective::Customer.where(user_id: user.id).first_or_create
    end

    def stripe_customer
      @stripe_customer ||= if stripe_customer_id.present?
        ::Stripe::Customer.retrieve(stripe_customer_id)
      else
        ::Stripe::Customer.create(email: user.email, description: user.id.to_s).tap do |stripe_customer|
          self.update_attributes(stripe_customer_id: stripe_customer.id)
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
          self.save!
        else
          raise Exception.new('unable to update stripe customer with new card')
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
