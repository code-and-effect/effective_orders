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

    delegate :title, :tax_exempt, :tax_rate, :to => :purchasable

    default_scope -> { order(:updated_at) }

    def price
      if (purchasable.price || 0).kind_of?(Integer)
        purchasable.price || 0
      else
        ActiveSupport::Deprecation.warn('price is a non-integer. It should be an Integer representing the number of cents.  Continuing with (price * 100.0).round(0).to_i conversion') unless EffectiveOrders.silence_deprecation_warnings
        (purchasable.price * 100.0).round(0).to_i rescue 0
      end
    end

    def subtotal
      price * quantity
    end

    def tax
      tax_exempt ? 0 : (subtotal * tax_rate).round(0).to_i
    end

    def total
      subtotal + tax
    end
  end
end
