class Product < ActiveRecord::Base
  acts_as_purchasable

  after_purchase do |order, order_item|
  end

  after_decline do |order, order_item|
  end
end
