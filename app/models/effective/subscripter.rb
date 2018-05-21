# Form object to select a plan, and build the correct subscription and customer

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :user, :subscribable, :customer
    attr_accessor :subscribable_global_id, :stripe_token, :stripe_plan_id, :include_trial

    validates :user, presence: true
    validates :subscribable, presence: true, if: -> { stripe_plan_id.present? }
    validates :customer, presence: true

    validates :stripe_plan_id, inclusion: { allow_blank: true, in: EffectiveOrders.stripe_plans.keys, message: 'unknown plan' }

    validate(if: -> { stripe_plan_id && plan && plan[:amount] > 0 }) do
      self.errors.add(:stripe_token, 'updated payment card required') if stripe_token.blank? && token_required?
    end

    def customer
      @customer ||= Effective::Customer.deep.where(user: user).first_or_initialize
    end

    def subscribable_global_id
      subscribable&.to_global_id
    end

    def subscribable_global_id=(global_id)
      @subscribable = GlobalID::Locator.locate(global_id)
    end

    def user_id=(id)
      @user = User.find(id)
    end

    def current_plan
      subscribable&.subscription&.plan
    end

    def plan
      EffectiveOrders.stripe_plans[stripe_plan_id]
    end

    def stripe_plan_id
      @stripe_plan_id || (current_plan[:id] if current_plan)
    end

    def token_required?
      customer.token_required?
    end

    def save!
      return true if (plan == current_plan) && stripe_token.blank?  # No work to do

      raise 'is invalid' unless valid?

      create_customer!
      create_stripe_token!
      build_subscription!
      sync_subscription!
      true
    end

    def destroy!
      return true unless plan

      subscribable.subscription.destroy!
      subscribable.update_column(:subscription_status, nil)
      sync_subscription!
      true
    end

    protected

    # This should work even if the rest of the form doesn't. Careful with our transactions...
    def create_customer!
      if customer.stripe_customer.blank?
        Rails.logger.info "STRIPE CUSTOMER CREATE: #{user.email}"
        customer.stripe_customer = Stripe::Customer.create(email: user.email, description: user.to_s, metadata: { user_id: user.id })
        customer.stripe_customer_id = customer.stripe_customer.id
        customer.save!
      end
    end

    # Update stripe customer card
    def create_stripe_token!
      if stripe_token.present?
        Rails.logger.info "STRIPE CUSTOMER SOURCE UPDATE #{stripe_token}"
        customer.stripe_customer.source = stripe_token
        customer.stripe_customer.save

        if customer.stripe_customer.default_source.present?
          card = customer.stripe_customer.sources.retrieve(customer.stripe_customer.default_source)
          customer.active_card = "**** **** **** #{card.last4} #{card.brand} #{card.exp_month}/#{card.exp_year}"
          customer.save!
        end
      end
    end

    def build_subscription!
      return unless plan.present?
      subscription.stripe_plan_id = plan[:id]
    end

    def sync_subscription!
      return unless plan.present?
      customer.stripe_subscription.blank? ? create_subscription! : update_subscription!

      customer.save!
    end

    def create_subscription!
      return unless plan.present?
      return if customer.stripe_subscription.present?

      Rails.logger.info "STRIPE SUBSCRIPTION CREATE: #{items(metadata: false)}"
      customer.stripe_subscription = Stripe::Subscription.create(customer: customer.stripe_customer_id, items: items(metadata: false), metadata: metadata)
      customer.stripe_subscription_id = customer.stripe_subscription.id

      customer.status = customer.stripe_subscription.status
      customer.stripe_subscription_interval = customer.stripe_subscription.plan.interval
    end

    def update_subscription!
      return unless plan.present?
      return if customer.stripe_subscription.blank?

      Rails.logger.info "STRIPE SUBSCRIPTION SYNC: #{customer.stripe_subscription_id} #{items}"

      if items.length == 0
        customer.stripe_subscription.delete
        customer.stripe_subscription_id = nil
        customer.status = EffectiveOrders::CANCELED
        return
      end

      # Update stripe subscription items
      customer.stripe_subscription.items.each do |stripe_item|
        item = items.find { |item| item[:plan] == stripe_item['plan']['id'] }

        next if item.blank? || item[:quantity] == stripe_item['quantity']

        stripe_item.quantity = item[:quantity]
        stripe_item.metadata = item[:metadata]

        Rails.logger.info " -> UPDATE: #{item[:plan]}"
        stripe_item.save
      end

      # Create stripe subscription items
      items.each do |item|
        next if customer.stripe_subscription.items.find { |stripe_item| item[:plan] == stripe_item['plan']['id'] }

        Rails.logger.info " -> CREATE: #{item[:plan]}"
        customer.stripe_subscription.items.create(plan: item[:plan], quantity: item[:quantity], metadata: item[:metadata])
      end

      # Delete stripe subscription items
      customer.stripe_subscription.items.each do |stripe_item|
        next if items.find { |item| item[:plan] == stripe_item['plan']['id'] }

        Rails.logger.info " -> DELETE: #{stripe_item['plan']['id']}"
        stripe_item.delete
      end

      # Update metadata
      if customer.stripe_subscription.metadata.to_h != metadata
        Rails.logger.info " -> METATADA: #{metadata}"
        customer.stripe_subscription.metadata = metadata
        customer.stripe_subscription.save
      end

      # When upgrading a plan, invoice immediately.
      # if current_plan && current_plan[:id] != 'trial' && plan[:amount] > current_plan[:amount]
      #   Rails.logger.info " -> INVOICE GENERATED"
      #   Stripe::Invoice.create(customer: customer.stripe_customer_id).pay rescue false
      # end

      customer.status = customer.stripe_subscription.status
    end

    def subscribe!(stripe_plan_id)
      self.stripe_plan_id = stripe_plan_id
      save!
    end

    private

    def subscription
      return nil unless subscribable
      customer.subscriptions.find { |sub| sub.subscribable == subscribable } || customer.subscriptions.build(subscribable: subscribable, customer: customer)
    end

    def items(metadata: true)
      customer.subscriptions.group_by { |sub| sub.stripe_plan_id }.map do |plan, subscriptions|
        if metadata
          { plan: plan, quantity: subscriptions.length, metadata: metadata(subscriptions: subscriptions) }
        else
          { plan: plan, quantity: subscriptions.length }
        end
      end
    end

    # The stripe metadata limit is 500 characters
    def metadata(subscriptions: nil)
      retval = { user_id: user.id.to_s, user: user.to_s.truncate(500) }

      (subscriptions || customer.subscriptions).group_by { |sub| sub.subscribable_type }.each do |subscribable_type, subs|
        subs = subs.sort

        if subs.length == 1
          retval[subscribable_type.downcase + '_id'] = subs.map { |sub| sub.subscribable.id }.join(',')
          retval[subscribable_type.downcase] = subs.map { |sub| sub.subscribable.to_s }.join(',').truncate(500)
        else
          retval[subscribable_type.downcase + '_ids'] = subs.map { |sub| sub.subscribable.id }.join(',')
          retval[subscribable_type.downcase.pluralize] = subs.map { |sub| sub.subscribable.to_s }.join(',').truncate(500)
        end
      end

      retval
    end

  end
end
