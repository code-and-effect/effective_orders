module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :stripe_customer

    belongs_to :user
    has_many :subscriptions, -> { includes(:subscribable) }, class_name: 'Effective::Subscription', foreign_key: 'customer_id'
    accepts_nested_attributes_for :subscriptions

    # Attributes
    # stripe_customer_id            :string  # cus_xja7acoa03
    # active_card                   :string  # **** **** **** 4242 Visa 05/12

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

    def email
      user.email if user
    end

    def stripe_customer
      @stripe_customer ||= if stripe_customer_id.present?
        Rails.logger.info "[STRIPE] get customer: #{stripe_customer_id}"
        ::Stripe::Customer.retrieve(stripe_customer_id)
      end
    end

    def upcoming_invoice
      @upcoming_invoice ||= if stripe_customer_id.present?
        Rails.logger.info "[STRIPE] get upcoming invoice: #{stripe_customer_id}"
        ::Stripe::Invoice.upcoming(customer: stripe_customer_id) rescue nil
      end
    end

    def token_required?
      active_card.blank? || (active_card.present? && subscriptions.any? { |sub| sub.past_due? })
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
