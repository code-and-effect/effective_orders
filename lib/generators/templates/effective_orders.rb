# EffectiveOrders Rails Engine

EffectiveOrders.setup do |config|
  config.orders_table_name = :orders
  config.order_items_table_name = :order_items
  config.carts_table_name = :carts
  config.cart_items_table_name = :cart_items

  config.authorization_method = Proc.new { |controller, action, resource| can?(action, resource) }
end
