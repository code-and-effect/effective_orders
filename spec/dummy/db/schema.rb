# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 4) do

  create_table "addresses", :force => true do |t|
    t.string   "addressable_type"
    t.integer  "addressable_id"
    t.string   "category",         :limit => 64
    t.string   "full_name"
    t.string   "address1"
    t.string   "address2"
    t.string   "city"
    t.string   "state_code"
    t.string   "country_code"
    t.string   "postal_code"
    t.datetime "updated_at"
    t.datetime "created_at"
  end

  add_index "addresses", ["addressable_id"], :name => "index_addresses_on_addressable_id"
  add_index "addresses", ["addressable_type", "addressable_id"], :name => "index_addresses_on_addressable_type_and_addressable_id"

  create_table "cart_items", :force => true do |t|
    t.integer  "cart_id"
    t.string   "purchasable_type"
    t.integer  "purchasable_id"
    t.integer  "quantity"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  add_index "cart_items", ["cart_id"], :name => "index_cart_items_on_cart_id"
  add_index "cart_items", ["purchasable_id"], :name => "index_cart_items_on_purchasable_id"
  add_index "cart_items", ["purchasable_type", "purchasable_id"], :name => "index_cart_items_on_purchasable_type_and_purchasable_id"

  create_table "carts", :force => true do |t|
    t.integer  "user_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "carts", ["user_id"], :name => "index_carts_on_user_id"

  create_table "custom_products", force: :true do |t|
    t.string   "title"
    t.integer  "price",       default: 0
    t.boolean  "tax_exempt"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "customers", force: true do |t|
    t.integer  "user_id"
    t.string   "stripe_customer_id"
    t.string   "stripe_active_card"
    t.string   "stripe_connect_access_token"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "order_items", :force => true do |t|
    t.integer  "order_id"
    t.integer  "seller_id"
    t.string   "purchasable_type"
    t.integer  "purchasable_id"
    t.string   "title"
    t.integer  "quantity"
    t.integer  "price",                :default => 0
    t.boolean  "tax_exempt"
    t.decimal  "tax_rate",             :precision => 5, :scale => 3, :default => 0.0
    t.datetime "created_at",                                                          :null => false
    t.datetime "updated_at",                                                          :null => false
  end

  add_index "order_items", ["order_id"], :name => "index_order_items_on_order_id"
  add_index "order_items", ["purchasable_id"], :name => "index_order_items_on_purchasable_id"
  add_index "order_items", ["purchasable_type", "purchasable_id"], :name => "index_order_items_on_purchasable_type_and_purchasable_id"

  create_table "orders", :force => true do |t|
    t.integer  "user_id"
    t.string   "purchase_state"
    t.datetime "purchased_at"
    t.text     "payment"
    t.text     "details"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
    t.text     "note"
    t.integer  "total"
    t.integer  "subtotal"
    t.integer  "tax"
    t.string   "payment_provider"
    t.string   "payment_card"
  end

  add_index "orders", ["user_id"], :name => "index_orders_on_user_id"

  create_table "products", :force => true do |t|
    t.string   "title"
    t.integer  "price",                :default => 0
    t.boolean  "tax_exempt"
    t.datetime "created_at",                                                          :null => false
    t.datetime "updated_at",                                                          :null => false
  end

  create_table "product_with_float_prices", :force => true do |t|
    t.string   "title"
    t.decimal "price",                :default => 0
    t.boolean  "tax_exempt"
    t.datetime "created_at",                                                          :null => false
    t.datetime "updated_at",                                                          :null => false
  end

  create_table "subscriptions", force: true do |t|
    t.integer  "customer_id"
    t.string   "stripe_plan_id"
    t.string   "stripe_subscription_id"
    t.string   "stripe_coupon_id"
    t.string   "title"
    t.integer  "price",                  default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: true do |t|
    t.string   "encrypted_password"
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "confirmation_sent_at"
    t.datetime "confirmed_at"
    t.string   "confirmation_token"
    t.string   "unconfirmed_email"
    t.integer  "sign_in_count",          default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "email"
    t.integer  "roles_mask",             default: 0
    t.boolean  "archived",               default: false
    t.datetime "updated_at"
    t.datetime "created_at"
  end

end
