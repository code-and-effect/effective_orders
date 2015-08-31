module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :token # This is a convenience method so we have a place to store StripeConnect temporary access tokens

    belongs_to :user
    has_many :subscriptions, :inverse_of => :customer

    structure do
      stripe_customer_id            :string  # cus_xja7acoa03
      stripe_active_card            :string  # **** **** **** 4242 Visa 05/12
      stripe_connect_access_token   :string  # If using StripeConnect and this user is a connected Seller

      timestamps
    end

    validates_presence_of :user
    validates_uniqueness_of :user_id  # Only 1 customer per user may exist

    scope :customers, -> { where("#{EffectiveOrders.customers_table_name.to_s}.stripe_customer_id IS NOT NULL") }

    class << self
      def for_user(user)
        if user.present?
          Effective::Customer.where(:user_id => (user.try(:id) rescue user.to_i)).first_or_create
        end
      end
    end

    def stripe_customer
      @stripe_customer ||= if stripe_customer_id.present?
        ::Stripe::Customer.retrieve(stripe_customer_id)
      else
        ::Stripe::Customer.create(:email => user.email, :description => user.id.to_s).tap do |stripe_customer|
          self.update_attributes(:stripe_customer_id => stripe_customer.id)
        end
      end
    end

    def update_card!(token)
      if token.present? # Oh, so they want to use a new credit card...
        stripe_customer.card = token  # This sets the default_card to the new card

        if stripe_customer.save && stripe_customer.default_card.present?
          card = stripe_customer.cards.retrieve(stripe_customer.default_card)

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

  end
end
