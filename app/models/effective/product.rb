module Effective
  class Product < ActiveRecord::Base
    self.table_name = EffectiveOrders.products_table_name.to_s

    acts_as_purchasable

    structure do
      title         :string, validates: [:presence]
      price         :integer, default: 0, validates: [numericality: { greater_than: 0 }]
      tax_exempt    :boolean, default: false

      timestamps
    end

    def to_s
      self[:title] || 'New Product'
    end

  end
end
