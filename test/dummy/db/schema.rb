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

ActiveRecord::Schema[8.1].define(version: 101) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "address1"
    t.string "address2"
    t.integer "addressable_id"
    t.string "addressable_type"
    t.string "category", limit: 64
    t.string "city"
    t.string "country_code"
    t.datetime "created_at", precision: nil
    t.string "full_name"
    t.string "postal_code"
    t.string "state_code"
    t.datetime "updated_at", precision: nil
    t.index ["addressable_id"], name: "index_addresses_on_addressable_id"
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable_type_and_addressable_id"
  end

  create_table "cart_items", force: :cascade do |t|
    t.integer "cart_id"
    t.datetime "created_at", null: false
    t.integer "purchasable_id"
    t.string "purchasable_type"
    t.integer "quantity"
    t.string "unique"
    t.datetime "updated_at", null: false
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["purchasable_id"], name: "index_cart_items_on_purchasable_id"
    t.index ["purchasable_type", "purchasable_id"], name: "index_cart_items_on_purchasable_type_and_purchasable_id"
  end

  create_table "carts", force: :cascade do |t|
    t.integer "cart_items_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "user_type"
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "active_card"
    t.datetime "created_at", null: false
    t.string "payment_method_id"
    t.string "status"
    t.string "stripe_customer_id"
    t.integer "subscriptions_count", default: 0
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "user_type"
    t.index ["user_id"], name: "index_customers_on_user_id"
  end

  create_table "email_templates", force: :cascade do |t|
    t.string "bcc"
    t.text "body"
    t.string "cc"
    t.string "content_type"
    t.datetime "created_at", precision: nil
    t.string "from"
    t.string "subject"
    t.string "template_name"
    t.datetime "updated_at", precision: nil
  end

  create_table "item_names", force: :cascade do |t|
    t.boolean "archived", default: false
    t.datetime "created_at", precision: nil
    t.string "name"
    t.datetime "updated_at", precision: nil
    t.index ["name", "archived"], name: "index_item_names_on_name_and_archived"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "order_id"
    t.integer "price"
    t.integer "purchasable_id"
    t.string "purchasable_type"
    t.integer "quantity"
    t.boolean "tax_exempt"
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["purchasable_id"], name: "index_order_items_on_purchasable_id"
    t.index ["purchasable_type", "purchasable_id"], name: "index_order_items_on_purchasable_type_and_purchasable_id"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "amount_owing"
    t.string "billing_first_name"
    t.string "billing_last_name"
    t.string "billing_name"
    t.string "cc"
    t.datetime "created_at", null: false
    t.boolean "delayed_payment", default: false
    t.date "delayed_payment_date"
    t.text "delayed_payment_intent"
    t.datetime "delayed_payment_purchase_ran_at", precision: nil
    t.text "delayed_payment_purchase_result"
    t.integer "delayed_payment_total"
    t.string "email"
    t.text "note"
    t.text "note_internal"
    t.text "note_to_buyer"
    t.integer "organization_id"
    t.string "organization_type"
    t.integer "parent_id"
    t.string "parent_type"
    t.text "payment"
    t.string "payment_card"
    t.string "payment_provider"
    t.datetime "purchased_at", precision: nil
    t.integer "purchased_by_id"
    t.string "purchased_by_type"
    t.string "status"
    t.text "status_steps"
    t.integer "subtotal"
    t.integer "surcharge"
    t.decimal "surcharge_percent", precision: 6, scale: 3
    t.integer "surcharge_tax"
    t.integer "tax"
    t.decimal "tax_rate", precision: 6, scale: 3
    t.integer "total"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "user_type"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "price"
    t.integer "purchased_order_id"
    t.string "qb_item_name"
    t.boolean "tax_exempt", default: false
    t.datetime "updated_at", null: false
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "customer_id"
    t.string "description"
    t.string "interval"
    t.string "name"
    t.integer "quantity"
    t.string "status"
    t.string "stripe_plan_id"
    t.string "stripe_subscription_id"
    t.integer "subscribable_id"
    t.string "subscribable_type"
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_subscriptions_on_customer_id"
    t.index ["subscribable_id"], name: "index_subscriptions_on_subscribable_id"
    t.index ["subscribable_type", "subscribable_id"], name: "index_subscriptions_on_subscribable_type_and_subscribable_id"
  end

  create_table "things", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "price"
    t.datetime "purchased_at", precision: nil
    t.integer "purchased_by_id"
    t.string "purchased_by_type"
    t.integer "purchased_order_id"
    t.string "qb_item_name"
    t.boolean "tax_exempt", default: false
    t.string "title"
    t.datetime "updated_at", precision: nil
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at", precision: nil
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.integer "roles_mask"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
