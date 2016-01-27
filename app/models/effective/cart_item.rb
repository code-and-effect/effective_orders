module Effective
  class CartItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.cart_items_table_name.to_s

    belongs_to :cart
    belongs_to :purchasable, :polymorphic => true

    structure do
      quantity    :integer

      timestamps
    end

    validates :purchasable, presence: true
    validates :quantity, presence: true

    default_scope -> { order(:updated_at) }

    def price
      if (purchasable.price || 0).kind_of?(Integer)
        purchasable.price || 0
      else
        ActiveSupport::Deprecation.warn('price is a non-integer. It should be an Integer representing the number of cents.  Continuing with (price * 100.0).round(0).to_i conversion') unless EffectiveOrders.silence_deprecation_warnings
        (purchasable.price * 100.0).round(0).to_i rescue 0
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
    alias_method :total, :subtotal

  end
end
