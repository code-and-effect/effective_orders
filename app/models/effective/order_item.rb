module Effective
  class OrderItem < ActiveRecord::Base
    self.table_name = EffectiveOrders.order_items_table_name.to_s

    belongs_to :order
    belongs_to :purchasable, :polymorphic => true

    structure do
      title                 :string, :validates => [:presence]
      quantity              :integer, :validates => [:presence, :numericality => {:greater_than => 0}]
      price                 :decimal, :precision => 8, :scale => 2, :default => 0.00
      tax_exempt            :boolean, :validates => [:inclusion => {:in => [true, false]}]
      tax_rate              :decimal, :precision => 5, :scale => 3, :default => 0.000, :validates => [:presence]
      quickbooks_item_name  :string

      timestamps
    end

    delegate :purchased, :declined, :to => :purchasable

    def subtotal
      price * quantity
    end

    def tax  # This is the total tax, for 3 items if quantity is 3
      tax_exempt ? 0.00 : (subtotal * tax_rate)
    end

    def total
      subtotal + tax
    end
  end
end
