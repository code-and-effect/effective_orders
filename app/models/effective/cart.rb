module Effective
  class Cart < ActiveRecord::Base
    self.table_name = (EffectiveOrders.carts_table_name || :carts).to_s

    belongs_to :user, polymorphic: true, optional: true  # Optional. We want non-logged-in users to have carts too.

    has_many :cart_items, -> { order(:id) }, inverse_of: :cart, dependent: :delete_all
    accepts_nested_attributes_for :cart_items

    effective_resource do
      cart_items_count        :integer

      timestamps
    end

    scope :deep, -> { includes(cart_items: :purchasable) }

    # cart.add(@product, unique: -> (a, b) { a.kind_of?(Product) && b.kind_of?(Product) && a.category == b.category })
    # cart.add(@product, unique: :category)
    # cart.add(@product, unique: false) # Add as many as you want
    def add(item, quantity: 1, unique: true)
      raise 'expecting an acts_as_purchasable object' unless item.kind_of?(ActsAsPurchasable)

      existing = (
        if unique.kind_of?(Proc)
          cart_items.find { |cart_item| instance_exec(item, cart_item.purchasable, &unique) }
        elsif unique.kind_of?(Symbol) || (unique.kind_of?(String) && unique != 'true')
          raise "expected item to respond to unique #{unique}" unless item.respond_to?(unique)
          cart_items.find { |cart_item| cart_item.purchasable.respond_to?(unique) && item.send(unique) == cart_item.purchasable.send(unique) }
        elsif unique.present?
          find(item)
        end
      )

      if existing
        if unique || (existing.unique.present?)
          existing.assign_attributes(purchasable: item, quantity: quantity, unique: existing.unique)
        else
          existing.quantity = existing.quantity + quantity
        end
      end

      if item.quantity_enabled? && (existing ? existing.quantity : quantity) > item.quantity_remaining
        raise EffectiveOrders::SoldOutException, "#{item.purchasable_name} is sold out"
      end

      existing ||= cart_items.build(purchasable: item, quantity: quantity, unique: (unique.to_s unless unique.kind_of?(Proc)))
      save!
    end

    def clear!
      cart_items.each { |cart_item| cart_item.mark_for_destruction }
      cart_items.present? ? save! : true
    end

    def remove(item)
      find(item).try(:mark_for_destruction)
      save!
    end

    def includes?(item)
      find(item).present?
    end

    def find(item)
      cart_items.find { |cart_item| cart_item == item || cart_item.purchasable == item }
    end

    def purchasables
      cart_items.map { |cart_item| cart_item.purchasable }
    end

    def size
      cart_items_count || cart_items.length
    end

    def present?
      size > 0
    end

    def blank?
      size <= 0
    end

    def subtotal
      cart_items.map { |ci| ci.subtotal }.sum
    end

  end
end
