module Effective
  class Cart < ActiveRecord::Base
    self.table_name = EffectiveOrders.carts_table_name.to_s

    belongs_to :user    # Optional. We want non-logged-in users to have carts too.
    has_many :cart_items, -> { includes(:purchasable).order(:updated_at) }, dependent: :delete_all, class_name: 'Effective::CartItem'

    accepts_nested_attributes_for :cart_items

    # Attributes
    # cart_items_count        :integer
    # timestamps

    scope :deep, -> { includes(cart_items: :purchasable) }

    # cart.add(@product, unique: -> (a, b) { a.kind_of?(Product) && b.kind_of?(Product) && a.category == b.category })
    # cart.add(@product, unique: :category)
    # cart.add(@product, unique: false) # Add as many as you want
    def add(item, quantity: 1, unique: true)
      raise 'expecting an acts_as_purchasable object' unless item.kind_of?(ActsAsPurchasable)

      existing = (
        if unique.kind_of?(Proc)
          cart_items.find { |cart_item| instance_exec(item, cart_item.purchasable, &unique) }
        elsif unique.kind_of?(Symbol)
          raise 'expected item to respond to unique symbol' unless item.respond_to?(unique)
          cart_items.find { |cart_item| cart_item.purchasable.respond_to?(unique) && item.send(unique) == cart_item.purchasable.send(unique) }
        elsif unique
          find(item)
        end
      )

      if existing
        if unique || (existing.unique?)
          existing.assign_attributes(purchasable: item, quantity: quantity, unique: true)
        else
          existing.quantity = existing.quantity + quantity
        end
      end

      if item.quantity_enabled? && (existing ? existing.quantity : quantity) > item.quantity_remaining
        raise EffectiveOrders::SoldOutException, "#{item.title} is sold out"
      end

      existing ||= cart_items.build(purchasable: item, quantity: quantity, unique: unique.present?)
      save!
    end

    def clear!
      cart_items.each { |cart_item| cart_item.mark_for_destruction }
      save!
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
