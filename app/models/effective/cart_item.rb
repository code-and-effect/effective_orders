module Effective
  class CartItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.cart_items_table_name.to_s

    belongs_to :cart
    belongs_to :purchasable, :polymorphic => true

    structure do
      quantity    :integer, :validates => [:presence]
      timestamps
    end

    validates_presence_of :purchasable

    delegate :title, :price, :tax_exempt, :quickbooks_item_name, :to => :purchasable

    default_scope order(:updated_at)

    def subtotal
      price * quantity
    end

    def tax
      tax_exempt ? 0.00 : (subtotal * tax_rate)
    end

    def tax_rate
      0.05   # this is the entry point for all tax stuff.  Right now we're hardcording it.
    end

    def total
      subtotal + tax
    end
  end
end
