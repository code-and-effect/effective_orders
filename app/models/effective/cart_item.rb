module Effective
  class CartItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.cart_items_table_name.to_s

    belongs_to :cart, counter_cache: true, class_name: 'Effective::Cart'
    belongs_to :purchasable, polymorphic: true

    # Attributes
    # quantity    :integer
    # timestamps

    validates :purchasable, presence: true
    validates :quantity, presence: true

    def price
      if (purchasable.price || 0).kind_of?(Integer)
        purchasable.price || 0
      else
        raise 'expected price to be an Integer representing the number of cents.'
      end
    end

    def title
      purchasable.try(:title) || 'New Cart Item'
    end

    def tax_exempt
      purchasable.try(:tax_exempt) || false
    end

    def subtotal
      price * quantity
    end

  end
end
