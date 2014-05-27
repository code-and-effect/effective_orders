class CreateEffectiveOrders < ActiveRecord::Migration
  def self.up
    create_table :orders do |t|
      t.integer   :user_id
      t.string    :purchase_state
      t.datetime  :purchased_at

      t.text      :payment

      t.timestamps
    end

    add_index :orders, :user_id

    create_table :order_items do |t|
      t.integer   :order_id
      t.integer   :seller_id
      t.string    :purchasable_type
      t.integer   :purchasable_id

      t.string    :title
      t.integer   :quantity
      t.decimal   :price, :precision => 8, :scale => 2, :default => 0.0
      t.boolean   :tax_exempt
      t.decimal   :tax_rate, :precision => 5, :scale => 3, :default => 0.0

      t.string    :quickbooks_item_name

      t.timestamps
    end

    add_index :order_items, :order_id
    add_index :order_items, :purchasable_id
    add_index :order_items, [:purchasable_type, :purchasable_id]


    create_table :carts do |t|
      t.integer   :user_id
      t.timestamps
    end

    add_index :carts, :user_id


    create_table :cart_items do |t|
      t.integer   :cart_id
      t.string    :purchasable_type
      t.integer   :purchasable_id

      t.integer   :quantity

      t.timestamps
    end

    add_index :cart_items, :cart_id
    add_index :cart_items, :purchasable_id
    add_index :cart_items, [:purchasable_type, :purchasable_id]

    create_table :customers do |t|
      t.integer   :user_id
      t.string    :stripe_customer_id
      t.string    :stripe_active_card
      t.string    :stripe_connect_access_token
      t.text      :plans

      t.timestamps
    end

    add_index :customers, :user_id
  end

  def self.down
    drop_table :orders
    drop_table :order_items
    drop_table :carts
    drop_table :cart_items
    drop_table :customers
  end
end
