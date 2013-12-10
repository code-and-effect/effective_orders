module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    belongs_to :user

    structure do
      stripe_customer         :string  # cus_xja7acoa03
      stripe_active_card      :string  # **** **** **** 4242 Visa 05/12

      stripe_connect_access_token :string  # If using StripeConnect and this user is a Seller

      timestamps
    end

    validates_presence_of :user
    validates_uniqueness_of :user_id  # Only 1 customer per user may exist

    class << self
      def for_user(user)
        if user.present?
          Effective::Customer.where(:user_id => user.try(:id)).first_or_create
        end
      end

      def is_stripe_connect_seller?(user)
        for_user(user).stripe_connect_access_token.present?
      end

    end
  end
end
