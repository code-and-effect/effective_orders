class CreateEffectiveOrders < ActiveRecord::Migration[4.2]
  def self.up
    create_table :orders do |t|
      t.integer   :user_id
      t.string    :user_type

      t.integer   :organization_id
      t.string    :organization_type

      t.integer   :parent_id
      t.string    :parent_type

      t.string    :status
      t.text      :status_steps

      t.datetime  :purchased_at

      t.integer   :purchased_by_id
      t.string    :purchased_by_type

      t.text      :note
      t.text      :note_to_buyer
      t.text      :note_internal

      t.string    :billing_name
      t.string    :email
      t.string    :cc

      t.text      :payment
      t.string    :payment_provider
      t.string    :payment_card

      t.decimal   :tax_rate, :precision => 6, :scale => 3
      t.decimal   :surcharge_percent, :precision => 6, :scale => 3

      t.integer   :subtotal
      t.integer   :tax
      t.integer   :amount_owing
      t.integer   :surcharge
      t.integer   :surcharge_tax
      t.integer   :total

      t.timestamps
    end

    add_index :orders, :user_id


    create_table :order_items do |t|
      t.integer   :order_id
      t.string    :purchasable_type
      t.integer   :purchasable_id

      t.string    :name
      t.integer   :quantity
      t.integer   :price
      t.boolean   :tax_exempt

      t.timestamps
    end

    add_index :order_items, :order_id
    add_index :order_items, :purchasable_id
    add_index :order_items, [:purchasable_type, :purchasable_id]


    create_table :carts do |t|
      t.integer   :user_id
      t.string    :user_type

      t.integer   :cart_items_count, :default => 0
      t.timestamps
    end

    add_index :carts, :user_id

    create_table :cart_items do |t|
      t.integer   :cart_id
      t.string    :purchasable_type
      t.integer   :purchasable_id

      t.string    :unique
      t.integer   :quantity

      t.timestamps
    end

    add_index :cart_items, :cart_id
    add_index :cart_items, :purchasable_id
    add_index :cart_items, [:purchasable_type, :purchasable_id]

    create_table :customers do |t|
      t.integer   :user_id
      t.string    :user_type

      t.string    :stripe_customer_id
      t.string    :payment_method_id
      t.string    :active_card
      t.string    :status

      t.integer   :subscriptions_count, :default => 0

      t.timestamps
    end

    add_index :customers, :user_id

    create_table :subscriptions do |t|
      t.integer   :customer_id

      t.integer   :subscribable_id
      t.string    :subscribable_type

      t.string    :stripe_plan_id
      t.string    :stripe_subscription_id

      t.string    :name
      t.string    :description
      t.string    :interval
      t.integer   :quantity
      t.string    :status

      t.timestamps
    end

    add_index :subscriptions, :customer_id
    add_index :subscriptions, :subscribable_id
    add_index :subscriptions, [:subscribable_type, :subscribable_id]

    create_table :products do |t|
      t.integer   :purchased_order_id

      t.string    :name
      t.integer   :price
      t.boolean   :tax_exempt, :default => false

      t.string    :qb_item_name

      t.timestamps
    end

  end

  def self.down
    drop_table :orders
    drop_table :order_items
    drop_table :carts
    drop_table :cart_items
    drop_table :customers
    drop_table :subscriptions
    drop_table :products
  end
end
