module Effective
  class CartItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.cart_items_table_name.to_s

    belongs_to :cart, counter_cache: true
    belongs_to :purchasable, polymorphic: true

    effective_resource do
      unique      :string
      quantity    :integer

      timestamps
    end

    validates :purchasable, presence: true
    validates :quantity, presence: true

    def to_s
      name || 'New Cart Item'
    end

    def name
      purchasable&.purchasable_name
    end

    def price
      if (purchasable.price || 0).kind_of?(Integer)
        purchasable.price || 0
      else
        raise 'expected price to be an Integer representing the number of cents.'
      end
    end

    def tax_exempt
      purchasable&.tax_exempt || false
    end

    def subtotal
      price * quantity
    end

  end
end
