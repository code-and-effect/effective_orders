class Product < ActiveRecord::Base
  acts_as_purchasable

  structure do
    price               :integer, :default => 0
    title               :string
    tax_exempt          :boolean

    timestamps
  end

  after_purchase do |order, order_item|
  end

  after_decline do |order, order_item|
  end
end
