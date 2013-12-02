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

ActiveRecord::Schema.define(:version => 3) do

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

  create_table "order_items", :force => true do |t|
    t.integer  "order_id"
    t.string   "purchasable_type"
    t.integer  "purchasable_id"
    t.string   "title"
    t.integer  "quantity"
    t.decimal  "price",                :precision => 8, :scale => 2, :default => 0.0
    t.boolean  "tax_exempt"
    t.decimal  "tax_rate",             :precision => 5, :scale => 3, :default => 0.0
    t.string   "quickbooks_item_name"
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
  end

  add_index "orders", ["user_id"], :name => "index_orders_on_user_id"

  create_table "products", :force => true do |t|
    t.string   "title"
    t.decimal  "price",      :precision => 8, :scale => 2, :default => 0.0
    t.boolean  "tax_exempt"
    t.datetime "created_at",                                                :null => false
    t.datetime "updated_at",                                                :null => false
  end

end
