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

    delegate :title, :price, :tax_exempt, :tax_rate :to => :purchasable

    default_scope -> { order(:updated_at) }

    def subtotal
      price * quantity
    end

    def tax
      tax_exempt ? 0.00 : (subtotal * tax_rate)
    end

    def total
      subtotal + tax
    end
  end
end
