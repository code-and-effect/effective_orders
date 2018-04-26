# Form object to select a plan, and build the correct subscription and customer

module Effective
  class Subscripter
    include ActiveModel::Model

    attr_accessor :user, :subscribable, :customer
    attr_accessor :subscribable_global_id, :stripe_token, :stripe_plan_id, :include_trial

    validates :user, presence: true
    validates :subscribable, presence: true
    validates :customer, presence: true

    validates :stripe_plan_id, inclusion: { in: EffectiveOrders.stripe_plans.keys, message: 'unknown plan' }

    validate(if: -> { stripe_plan_id && plan && subscribable }) do
      if plan[:amount] > 0 && stripe_token.blank? && token_required?
        self.errors.add(:stripe_token, 'updated payment card required')
      end
    end

    # validate do
    #   self.errors.add(:stripe_token, 'no you dont')
    # end

    # validate(if: -> { subscribable }) do
    #   subscribable.errors.add(:subscripter, errors.messages.values.flatten.to_sentence) if self.errors.present?
    # end

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
      subscribable.subscription&.plan
    end

    def plan
      EffectiveOrders.stripe_plans[stripe_plan_id]
    end

    def token_required?
      customer.token_required?
    end

    def save!
      return true if (plan == current_plan) && stripe_token.blank?  # No work to do

      raise 'is invalid' unless valid?

      create_customer!

      begin
        build! && sync! && customer.save!
      rescue => e
        reload!

        self.errors.add(:base, e.message)
        raise e
      end
    end

    # This should work even if the rest of the form doesn't. Careful with our transactions...
    def create_customer!
      if customer.stripe_customer.blank?
        Rails.logger.info "STRIPE CUSTOMER CREATE: #{user.email}"
        customer.stripe_customer = Stripe::Customer.create(email: user.email, description: user.to_s, metadata: { user_id: user.id })
        customer.stripe_customer_id = customer.stripe_customer.id
        customer.save!
      end
    end

    def subscribe!(stripe_plan_id)
      self.stripe_plan_id = stripe_plan_id
      save!
    end

    def destroy!
      return true unless subscription && subscription.persisted? && customer.stripe_subscription.present?

      raise 'is invalid' unless valid?

      subscription.destroy!
      customer.subscriptions.reload

      sync! && customer.save!
    end

    def reload!
      @stripe_token = nil
      @stripe_plan_id = nil
      @customer = nil
      @subscription = nil
    end

    private

    def subscription
      return nil unless subscribable
      @subscription ||= (
        customer.subscriptions.find { |sub| sub.subscribable == subscribable } ||
        customer.subscriptions.build(subscribable: subscribable, customer: customer)
      )
    end

    def build!
      # Update stripe customer card
      if stripe_token.present?
        Rails.logger.info "STRIPE CUSTOMER SOURCE UPDATE #{stripe_token}"
        customer.stripe_customer.source = stripe_token
        customer.stripe_customer.save

        if customer.stripe_customer.default_source.present?
          card = customer.stripe_customer.sources.retrieve(customer.stripe_customer.default_source)
          customer.active_card = "**** **** **** #{card.last4} #{card.brand} #{card.exp_month}/#{card.exp_year}"
        end
      end

      # Assign stripe plan
      if plan.present?
        subscription.stripe_plan_id = plan[:id]

        # Ensure stripe subscription exists
        if customer.stripe_subscription.blank?
          Rails.logger.info "STRIPE SUBSCRIPTION CREATE: #{items(metadata: false)}"
          customer.stripe_subscription = Stripe::Subscription.create(customer: customer.stripe_customer_id, items: items(metadata: false), metadata: metadata)
          customer.stripe_subscription_id = customer.stripe_subscription.id
        end
      end

      true
    end

    def sync!
      return true unless plan && customer.stripe_subscription

      Rails.logger.info "STRIPE SUBSCRIPTION SYNC: #{customer.stripe_subscription_id} #{items}"

      if items.length == 0
        customer.stripe_subscription.delete
        customer.stripe_subscription_id = nil
        customer.status = nil
        return true
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

      # Sync status
      customer.status = customer.stripe_subscription.status

      true
    end

    private

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
