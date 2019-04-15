# Form object to select a plan, and build the correct subscription and customer

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :current_user, :user, :subscribable, :customer
    attr_accessor :subscribable_global_id, :stripe_token, :stripe_plan_id, :quantity

    validates :user, presence: true
    validates :subscribable, presence: true, if: -> { stripe_plan_id.present? }
    validates :customer, presence: true

    validates :stripe_plan_id, inclusion: { allow_blank: true, in: EffectiveOrders.stripe_plans.keys, message: 'unknown plan' }

    validate(if: -> { stripe_plan_id && plan && plan[:amount] > 0 }) do
      self.errors.add(:stripe_token, 'updated payment card required') if stripe_token.blank? && token_required?
    end

    validate(if: -> { stripe_plan_id && subscribable }) do
      quantity_used = [subscribable.subscribable_quantity_used, 0].max
      self.errors.add(:quantity, "must be #{quantity_used} or greater") unless quantity >= quantity_used
    end

    def to_s
      'Your Plan'
    end

    def customer
      @customer ||= Effective::Customer.deep.where(user: user).first_or_initialize
    end

    def current_user=(user)
      @user = user
    end

    def subscribable_global_id
      subscribable&.to_global_id
    end

    def subscribable_global_id=(global_id)
      @subscribable = GlobalID::Locator.locate(global_id)
    end

    def plan
      EffectiveOrders.stripe_plans[stripe_plan_id]
    end

    def quantity=(value)
      @quantity = (value.to_i if value)
    end

    def token_required?
      customer.token_required?
    end

    def save!
      raise 'is invalid' unless valid?

      create_customer!
      create_stripe_token!
      save_subscription!
      true
    end

    def destroy!
      return true unless plan

      subscription = subscribable.subscription

      Rails.logger.info " -> [STRIPE] delete subscription"
      subscription.stripe_subscription.delete
      subscription.destroy!
      
      true
    end

    protected

    def create_customer!
      return if customer.stripe_customer.present?

      Rails.logger.info "[STRIPE] create customer: #{user.email}"
      customer.stripe_customer = Stripe::Customer.create(email: user.email, description: user.to_s, metadata: { user_id: user.id })
      customer.stripe_customer_id = customer.stripe_customer.id
      customer.save!
    end

    # Update stripe customer card
    def create_stripe_token!
      return if stripe_token.blank?

      Rails.logger.info "[STRIPE] update source: #{stripe_token}"
      customer.stripe_customer.source = stripe_token
      customer.stripe_customer.save

      return if customer.stripe_customer.default_source.blank?

      card = customer.stripe_customer.sources.retrieve(customer.stripe_customer.default_source)
      customer.active_card = "**** **** **** #{card.last4} #{card.brand} #{card.exp_month}/#{card.exp_year}"
      customer.save!
    end

    def save_subscription!
      return unless plan.present?

      subscription.assign_attributes(stripe_plan_id: stripe_plan_id, quantity: quantity)

      cancel_subscription!
      create_subscription! || update_subscription!
      true
    end

    def cancel_subscription!
      return false unless subscription.persisted? && subscription.stripe_plan_id_changed?

      item = items.first
      stripe_item = subscription.stripe_subscription.items.first

      return false unless stripe_item.present? && item[:plan] != stripe_item['plan']['id']

      Rails.logger.info " -> [STRIPE] cancel plan: #{stripe_item['plan']['id']}"
      subscription.stripe_subscription.delete
      subscription.assign_attributes(stripe_subscription: nil, stripe_subscription_id: nil)

      true
    end

    def create_subscription!
      return false unless subscription.stripe_subscription.blank?

      Rails.logger.info "[STRIPE] create subscription: #{items}"
      stripe_subscription = Stripe::Subscription.create(customer: customer.stripe_customer_id, items: items, metadata: metadata)

      subscription.update!(
        stripe_subscription: stripe_subscription,
        stripe_subscription_id: stripe_subscription.id,
        status: stripe_subscription.status,
        name: stripe_subscription.plan.nickname,
        interval: stripe_subscription.plan.interval,
        quantity: quantity
      )
    end

    def update_subscription!
      return false unless subscription.stripe_subscription.present?

      stripe_item = subscription.stripe_subscription.items.first
      item = items.first

      return false unless stripe_item.present? && item[:plan] == stripe_item['plan']['id']
      return false unless item[:quantity] != subscription.stripe_subscription.quantity

      Rails.logger.info " -> [STRIPE] update plan: #{item[:plan]}"
      stripe_item.quantity = item[:quantity]
      stripe_item.save

      subscription.update!(status: subscription.stripe_subscription.status)

      # Invoice immediately
      Rails.logger.info " -> [STRIPE] generate invoice"
      Stripe::Invoice.create(customer: customer.stripe_customer_id).pay

      true
    end

    private

    def subscription
      return nil unless subscribable
      customer.subscriptions.find { |sub| sub.subscribable == subscribable } || customer.subscriptions.build(subscribable: subscribable, customer: customer)
    end

    def items
      [{ plan: subscription.stripe_plan_id, quantity: subscription.quantity }]
    end

    # The stripe metadata limit is 500 characters
    def metadata
      {
        :user_id => user.id.to_s,
        :user => user.to_s.truncate(500),
        (subscription.subscribable_type.downcase + '_id').to_sym => subscription.subscribable.id.to_s,
        subscription.subscribable_type.downcase.to_sym => subscription.subscribable.to_s
      }
    end

  end
end
