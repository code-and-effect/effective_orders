module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :stripe_source # This is the stripe subscription tokene
    attr_accessor :token # This is a convenience method so we have a place to store StripeConnect temporary access tokens

    belongs_to :user
    has_many :subscriptions, class_name: 'Effective::Subscription', foreign_key: 'customer_id'
    has_many :subscribables, through: :subscriptions, source: :subscribable

    # Attributes
    # stripe_customer_id            :string  # cus_xja7acoa03
    # active_card                   :string  # **** **** **** 4242 Visa 05/12

    # stripe_subscription_id        :string  # Each user gets one stripe subscription object, which can contain many items
    # current_period_end            :datetime
    # status                        :string

    # stripe_connect_access_token   :string  # If using StripeConnect and this user is a connected Seller
    #
    # timestamps

    validates :user, presence: true
    validates :stripe_customer_id, if: -> { persisted? }, presence: true

    before_save(if: -> { stripe_customer_id.blank? }) do
      self.stripe_customer_id = stripe_customer.id
    end

    before_save(if: -> { stripe_source.present? }) do
      assign_card!(stripe_source)
    end

    before_save(if: -> { subscriptions.present? && stripe_subscription_id.blank? }) do
      self.stripe_subscription_id = stripe_subscription.id
      self.status = stripe_subscription.status
      self.current_period_end = Time.zone.at(stripe_subscription.current_period_end)
    end

    before_save(if: -> { subscriptions.any? { |sub| sub.changed? || sub.new_record? }}) do
      sync_subscription!
    end

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
      else
        Rails.logger.info "STRIPE CUSTOMER CREATE: #{user.email} and #{user.id}"
        ::Stripe::Customer.create(email: user.email, description: "User #{user.id}", metadata: { user_id: user.id })
      end
    end

    def stripe_subscription
      @stripe_subscription ||= if stripe_subscription_id.present?
        Rails.logger.info "STRIPE SUBSCRIPTION RETRIEVE: #{stripe_subscription_id}"
        ::Stripe::Subscription.retrieve(stripe_subscription_id)
      else
        Rails.logger.info "STRIPE SUBSCRIPTION CREATE: #{stripe_customer_id}"
        ::Stripe::Subscription.create(customer: stripe_customer_id, items: subscription_items(metadata: false), metadata: subscription_metadata)
      end
    end

    def stripe_source=(token)
      @stripe_source = token
      self.updated_at = Time.zone.now if token.present?
    end

    private

    def subscription_metadata
      { user_id: user.id.to_s, ids: subscriptions.map { |sub| sub.subscribable.id }.compact.sort.join(',') }
    end

    def subscription_items(metadata: true)
      subscriptions.group_by { |sub| sub.stripe_plan_id }.map do |plan, subs|
        if metadata
          { plan: plan, quantity: subs.length, metadata: { ids: subs.map { |sub| sub.subscribable.id }.compact.sort.join(',') } }
        else
          { plan: plan, quantity: subs.length }
        end
      end
    end

    def sync_subscription!
      Rails.logger.info "STRIPE SUBSCRIPTION SYNC: #{stripe_subscription_id} #{subscription_items}"

      # Update quantities
      stripe_subscription.items.each do |stripe_item|
        if(item = subscription_items.find { |item| item[:plan] == stripe_item['plan']['id'] })
          if item[:quantity] != stripe_item['quantity'] || item[:metadata] != stripe_item['metadata'].to_h
            stripe_item.quantity = item[:quantity]
            stripe_item.metadata = item[:metadata]
            Rails.logger.info " -> UPDATE: #{item[:plan]}"
            stripe_item.save
          end
        end
      end

      # Create new ones
      subscription_items.each do |item|
        unless stripe_subscription.items.find { |stripe_item| item[:plan] == stripe_item['plan']['id'] }
          Rails.logger.info " -> CREATE: #{item[:plan]}"
          stripe_subscription.items.create(plan: item[:plan], quantity: item[:quantity], metadata: item[:metadata])
        end
      end

      # Delete existing
      stripe_subscription.items.each do |stripe_item|
        if subscription_items.find { |item| item[:plan] == stripe_item['plan']['id'] }.blank?
          Rails.logger.info " -> DELETE: #{stripe_item['plan']['id']}"
          stripe_item.delete
        end
      end

      # Update metadata
      if stripe_subscription.metadata.to_h != subscription_metadata
        Rails.logger.info " -> METATADA: #{subscription_metadata}"
        stripe_subscription.metadata = subscription_metadata
        stripe_subscription.save
      end

      true
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
      assign_card(token)
      save!
    end

  end
end
