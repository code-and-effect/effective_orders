module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :token # This is a convenience method so we have a place to store StripeConnect temporary access tokens

    belongs_to :buyer, polymorphic: true  # Probably a User

    # Attributes
    # stripe_customer_id            :string  # cus_xja7acoa03
    # stripe_active_card            :string  # **** **** **** 4242 Visa 05/12
    # stripe_connect_access_token   :string  # If using StripeConnect and this buyer is a connected Seller
    #
    # timestamps

    scope :customers, -> { where.not(stripe_customer_id: nil) }

    before_validation(if: -> { stripe_customer_id.blank? && buyer.present? }) { stripe_customer }

    validates :buyer, presence: true
    validates :stripe_customer_id, presence: true

    # def self.for_buyer(buyer)
    #   Effective::Customer.where(buyer: buyer).first_or_create
    # end

    def stripe_customer
      @stripe_customer ||= if stripe_customer_id.present?
        ::Stripe::Customer.retrieve(stripe_customer_id)
      else
        raise 'must have a buyer assigned to create a stripe customer' unless buyer.present?
        raise "buyer email can't be blank" unless buyer.try(:email).present?

        description = "#{buyer.class.name} #{buyer.to_param}"

        Rails.logger.info "STRIPE CUSTOMER CREATE: #{buyer.email} and #{description}"

        ::Stripe::Customer.create(email: buyer.email, description: description).tap do |stripe_customer|
          self.stripe_customer_id = stripe_customer.id
        end
      end
    end

    # def update_card!(token)
    #   if token.present? # Oh, so they want to use a new credit card...
    #     if stripe_customer.respond_to?(:cards)
    #       stripe_customer.card = token  # This sets the default_card to the new card
    #     elsif stripe_customer.respond_to?(:sources)
    #       stripe_customer.source = token
    #     else
    #       raise 'unknown stripe card/source token method'
    #     end

    #     if stripe_customer.save && default_card.present?
    #       card = cards.retrieve(default_card)

    #       self.stripe_active_card = "**** **** **** #{card.last4} #{card.brand} #{card.exp_month}/#{card.exp_year}"
    #       self.save!
    #     else
    #       raise 'unable to update stripe customer with new card'
    #     end
    #   end
    # end

    # def is_stripe_connect_seller?
    #   stripe_connect_access_token.present?
    # end

    # def current_plan_ids
    #   @current_plan_ids ||= subscriptions.purchased.map { |subscription| subscription.stripe_plan_id }
    # end

    # private

    # def default_card
    #   if stripe_customer.respond_to?(:default_card)
    #     stripe_customer.default_card
    #   elsif stripe_customer.respond_to?(:default_source)
    #     stripe_customer.default_source
    #   else
    #     raise 'unknown stripe default card method'
    #   end
    # end

    # def cards
    #   if stripe_customer.respond_to?(:cards)
    #     stripe_customer.cards
    #   elsif stripe_customer.respond_to?(:sources)
    #     stripe_customer.sources
    #   else
    #     raise 'unknown stripe cards method'
    #   end
    # end
  end
end
