module Effective
  class Cart < ActiveRecord::Base
    self.table_name = EffectiveOrders.carts_table_name.to_s

    belongs_to :user    # This is optional.  We want to let non-logged-in people have carts too
    has_many :cart_items, :inverse_of => :cart, :dependent => :delete_all

    structure do
      timestamps
    end

    default_scope -> { includes(:cart_items => :purchasable) }

    def add(item, quantity = 1)
      raise 'expecting an acts_as_purchasable object' unless item.respond_to?(:is_effectively_purchasable?)

      existing_item = cart_items.where(:purchasable_id => item.id, :purchasable_type => item.class.name).first

      if item.quantity_enabled? && (quantity + (existing_item.quantity rescue 0)) > item.quantity_remaining
        raise EffectiveOrders::SoldOutException, "#{item.title} is sold out"
        return
      end

      if existing_item.present?
        existing_item.update_attributes(:quantity => existing_item.quantity + quantity)
      else
        cart_items.create(:cart => self, :purchasable_id => item.id, :purchasable_type => item.class.name, :quantity => quantity)
      end
    end
    alias_method :add_to_cart, :add

    def remove(obj)
      (cart_items.find(cart_item) || cart_item).try(:destroy)
    end
    alias_method :remove_from_cart, :remove

    def includes?(item)
      find(item).present?
    end

    def find(item)
      cart_items.to_a.find { |cart_item| cart_item == item || cart_item.purchasable == item }
    end

    def size
      cart_items.size
    end

    def empty?
      size == 0
    end

    def subtotal
      cart_items.map { |ci| ci.subtotal }.sum
    end

    def tax
      cart_items.map { |ci| ci.tax }.sum
    end

    def total
      cart_items.map { |ci| ci.total }.sum
    end
  end
end
