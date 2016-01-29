module Effective
  class Product < ActiveRecord::Base
    self.table_name = EffectiveOrders.products_table_name.to_s

    acts_as_purchasable

    validates :title, presence: true
    validates :price, numericality: { greater_than: 0 }

    def to_s
      self[:title] || 'New Product'
    end

  end
end
