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

    default_scope -> { order(:updated_at) }

    def subtotal
      price * quantity
    end

    def tax
      tax_exempt ? 0.00 : (subtotal * tax_rate)
    end

    def tax_rate
      @tax_rate ||= (
        self.instance_exec(purchasable, &EffectiveOrders.tax_rate_method).to_f.tap do |rate|
          raise ArgumentError.new("expected EffectiveOrders.tax_rate_method to return a value between 0 and 1. Received #{rate}. Please return 0.05 for 5% tax.") if (rate > 1.0 || rate < 0.0)
        end
      )
    end

    def total
      subtotal + tax
    end
  end
end
