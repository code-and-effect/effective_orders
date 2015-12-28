module Effective
  class CustomProduct < ActiveRecord::Base
    self.table_name = EffectiveOrders.custom_products_table_name.to_s

    acts_as_purchasable

    structure do
      description   :text, validates: [:presence]
      price         :integer, default: 0, validates: [numericality: { greater_than: 0 }]

      timestamps
    end

    def to_s
      description
    end
  end
end
