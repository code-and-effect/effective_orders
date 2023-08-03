# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 6) do

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "addressable_type"
    t.integer "addressable_id"
    t.string "category", limit: 64
    t.string "full_name"
    t.string "address1"
    t.string "address2"
    t.string "city"
    t.string "state_code"
    t.string "country_code"
    t.string "postal_code"
    t.datetime "updated_at"
    t.datetime "created_at"
    t.index ["addressable_id"], name: "index_addresses_on_addressable_id"
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable_type_and_addressable_id"
  end

  create_table "cart_items", force: :cascade do |t|
    t.integer "cart_id"
    t.string "purchasable_type"
    t.integer "purchasable_id"
    t.string "unique"
    t.integer "quantity"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["purchasable_id"], name: "index_cart_items_on_purchasable_id"
    t.index ["purchasable_type", "purchasable_id"], name: "index_cart_items_on_purchasable_type_and_purchasable_id"
  end

  create_table "carts", force: :cascade do |t|
    t.integer "user_id"
    t.string "user_type"
    t.integer "cart_items_count", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "customers", force: :cascade do |t|
    t.integer "user_id"
    t.string "user_type"
    t.string "stripe_customer_id"
    t.string "payment_method_id"
    t.string "active_card"
    t.string "status"
    t.integer "subscriptions_count", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_id"], name: "index_customers_on_user_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.integer "order_id"
    t.string "purchasable_type"
    t.integer "purchasable_id"
    t.string "name"
    t.integer "quantity"
    t.integer "price"
    t.boolean "tax_exempt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["purchasable_id"], name: "index_order_items_on_purchasable_id"
    t.index ["purchasable_type", "purchasable_id"], name: "index_order_items_on_purchasable_type_and_purchasable_id"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "user_id"
    t.string "user_type"
    t.integer "organization_id"
    t.string "organization_type"
    t.integer "parent_id"
    t.string "parent_type"
    t.string "state"
    t.datetime "purchased_at"
    t.integer "purchased_by_id"
    t.string "purchased_by_type"
    t.text "note"
    t.text "note_to_buyer"
    t.text "note_internal"
    t.string "billing_name"
    t.string "email"
    t.string "cc"
    t.text "payment"
    t.string "payment_provider"
    t.string "payment_card"
    t.decimal "tax_rate", precision: 6, scale: 3
    t.decimal "surcharge_percent", precision: 6, scale: 3
    t.integer "subtotal"
    t.integer "tax"
    t.integer "amount_owing"
    t.integer "surcharge"
    t.integer "surcharge_tax"
    t.integer "total"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.integer "purchased_order_id"
    t.string "name"
    t.integer "price"
    t.boolean "tax_exempt", default: false
    t.string "qb_item_name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer "customer_id"
    t.integer "subscribable_id"
    t.string "subscribable_type"
    t.string "stripe_plan_id"
    t.string "stripe_subscription_id"
    t.string "name"
    t.string "description"
    t.string "interval"
    t.integer "quantity"
    t.string "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["customer_id"], name: "index_subscriptions_on_customer_id"
    t.index ["subscribable_id"], name: "index_subscriptions_on_subscribable_id"
    t.index ["subscribable_type", "subscribable_id"], name: "index_subscriptions_on_subscribable_type_and_subscribable_id"
  end

  create_table "things", force: :cascade do |t|
    t.integer "purchased_order_id"
    t.integer "purchased_by_id"
    t.string "purchased_by_type"
    t.string "title"
    t.integer "price"
    t.boolean "tax_exempt", default: false
    t.string "qb_item_name"
    t.datetime "purchased_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "email", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.integer "roles_mask"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
