module Effective
  class Product < ActiveRecord::Base
    self.table_name = EffectiveOrders.products_table_name.to_s

    acts_as_purchasable
    log_changes if respond_to?(:log_changes)

    effective_resource do
      name          :string
      qb_item_name  :string

      price         :integer
      tax_exempt    :boolean

      timestamps
    end

    validates :name, presence: true
    validates :price, presence: true
    validates :tax_exempt, inclusion: { in: [true, false] }

    def to_s
      name || 'New Product'
    end

  end
end
