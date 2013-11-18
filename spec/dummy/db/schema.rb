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

ActiveRecord::Schema.define(:version => 20130530172203) do

  create_table "assets", :force => true do |t|
    t.string   "title"
    t.text     "description"
    t.string   "tags"
    t.integer  "user_id"
    t.string   "content_type"
    t.string   "upload_file"
    t.string   "data"
    t.boolean  "processed",     :default => false
    t.integer  "data_size"
    t.integer  "height"
    t.integer  "width"
    t.text     "versions_info"
    t.datetime "created_at",                       :null => false
    t.datetime "updated_at",                       :null => false
  end

  add_index "assets", ["content_type"], :name => "index_assets_on_content_type"

  create_table "attachments", :force => true do |t|
    t.integer "asset_id"
    t.string  "attachable_type"
    t.integer "attachable_id"
    t.integer "position"
    t.string  "box"
  end

  add_index "attachments", ["asset_id"], :name => "index_attachments_on_asset_id"
  add_index "attachments", ["attachable_id"], :name => "index_attachments_on_attachable_id"
  add_index "attachments", ["attachable_type", "attachable_id"], :name => "index_attachments_on_attachable_type_and_attachable_id"

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

end
