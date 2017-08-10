module Effective
  class Customer < ActiveRecord::Base
    self.table_name = EffectiveOrders.customers_table_name.to_s

    attr_accessor :stripe_source # This is the stripe subscription tokene
    attr_accessor :trial_end
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

    before_save(if: -> { subscriptions.any? { |sub| sub.changed? } || stripe_source.present? }) do
      sync_subscription!
      #::Stripe::Subscription.create(customer: stripe_customer_id, items: subscription_items, metadata: { user_id: user.id })
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
        Rails.logger.info "STRIPE SUBSCRIPTION CREATE: #{stripe_customer_id} #{subscription_items} #{trial_end}"

        ::Stripe::Subscription.create(
          customer: stripe_customer_id,
          items: subscription_items,
          metadata: subscription_metadata,
          trial_end: subscription_trial_end
        )
      end
    end

    def stripe_source=(token)
      @stripe_source = token
      self.updated_at = Time.zone.now if token.present?
    end

    def trialing?
      status == 'trialing'
    end

    # def stripe_trialing
    #   return @trialing unless @trialing.nil?

    #   @trialing = (
    #     persisted? && stripe_subscription_id && stripe_subscription &&
    #     stripe_subscription.trial_end.present? && (Time.zone.at(stripe_subscription.trial_end) > Time.zone.now)
    #   )
    # end

    private

    def subscription_trial_end
      trial_end.to_i if trial_end
      #subscriptions.map { |sub| sub.current_period_end }.compact.min.try(:to_i)
    end

    def subscription_metadata
      { user_id: user.id, ids: subscriptions.map { |sub| sub.subscribable.id }.compact.sort.join(',') }
    end

    def subscription_items
      subscriptions.group_by { |sub| sub.stripe_plan_id }.map do |plan, subs|
        { plan: plan, quantity: subs.length, metadata: { ids: subs.map { |sub| sub.subscribable.id }.compact.sort.join(',') } }
      end
    end

    def sync_subscription!
      Rails.logger.info "STRIPE SUBSCRIPTION UPDATE: #{stripe_subscription_id} #{subscription_items}"

      stripe_subscription.items.each do |stripe_item|
        if(item = subscription_items.find { |item| item[:plan] == stripe_item['plan']['id'] })
          if item[:quantity] != stripe_item['quantity'] || item[:metadata] != stripe_item['metadata'].to_h
            stripe_item.quantity = item[:quantity]
            stripe_item.metadata = item[:metadata]
            stripe_item.save
          end
        else
          stripe_item.delete
        end
      end

      subscription_items.each do |item|
        unless stripe_subscription.items.find { |stripe_item| item[:plan] == stripe_item['plan']['id'] }
          stripe_subscription.items.create(plan: item[:plan], quantity: item[:quantity], metadata: item[:metadata])
        end
      end

      stripe_subscription.metadata = subscription_metadata
      stripe_subscription.trial_end = 'now' if active_card.present?

      stripe_subscription.save
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
