module Effective
  class Cart < ActiveRecord::Base
    self.table_name = EffectiveOrders.carts_table_name.to_s

    belongs_to :user    # Optional. We want non-logged-in users to have carts too.
    has_many :cart_items, -> { order(:updated_at) }, dependent: :delete_all, class_name: 'Effective::CartItem'

    # Attributes
    # cart_items_count        :integer
    # timestamps

    scope :deep, -> { includes(cart_items: :purchasable) }

    def add(item, quantity: 1, unique: false)
      raise 'expecting an acts_as_purchasable object' unless item.kind_of?(ActsAsPurchasable)

      if unique
        cart_items.each { |cart_item| cart_item.destroy if cart_item.purchasable_type == item.class.name }
        quantity = 1
      end

      existing_item = cart_items.find { |cart_item| cart_item.purchasable_id == item.id && cart_item.purchasable_type == item.class.name }

      if item.quantity_enabled? && (quantity + (existing_item.quantity rescue 0)) > item.quantity_remaining
        raise EffectiveOrders::SoldOutException, "#{item.title} is sold out"
      end

      if existing_item.present?
        existing_item.update_attributes(quantity: existing_item.quantity + quantity)
      else
        self.cart_items.build(purchasable: item, quantity: quantity).save!
      end
    end

    def remove(obj)
      cart_items.find(obj).try(:destroy)
    end

    def includes?(item)
      find(item).present?
    end

    def find(item)
      cart_items.to_a.find { |cart_item| cart_item == item || cart_item.purchasable == item }
    end

    def size
      cart_items_count || cart_items.length
    end

    def empty?
      size == 0
    end

    def subtotal
      cart_items.map { |ci| ci.subtotal }.sum
    end

  end
end
