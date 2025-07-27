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

ActiveRecord::Schema[8.0].define(version: 2025_07_27_090025) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "uuid-ossp"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "image_url"
    t.boolean "active", default: true, null: false
    t.integer "sort_order", default: 0
    t.datetime "deleted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "active"], name: "index_categories_on_company_id_and_active"
    t.index ["company_id", "name"], name: "index_categories_on_company_id_and_name", unique: true, where: "(deleted_at IS NULL)"
    t.index ["company_id", "sort_order"], name: "index_categories_on_company_id_and_sort_order"
    t.index ["deleted_at"], name: "index_categories_on_deleted_at"
  end

  create_table "companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "address"
    t.string "phone"
    t.string "email"
    t.jsonb "settings", default: {}
    t.string "currency", default: "IDR", null: false
    t.string "timezone", default: "Asia/Jakarta", null: false
    t.boolean "active", default: true, null: false
    t.datetime "deleted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_companies_on_active"
    t.index ["created_at"], name: "index_companies_on_created_at"
    t.index ["deleted_at"], name: "index_companies_on_deleted_at"
    t.index ["email"], name: "index_companies_on_email", unique: true, where: "(deleted_at IS NULL)"
  end

  create_table "inventories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.uuid "item_id", null: false
    t.integer "stock", default: 0, null: false
    t.integer "minimum_stock", default: 0, null: false
    t.integer "reserved_stock", default: 0, null: false
    t.datetime "last_counted_at"
    t.datetime "deleted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "item_id"], name: "index_inventories_on_company_id_and_item_id", unique: true, where: "(deleted_at IS NULL)"
    t.index ["company_id", "stock"], name: "index_inventories_on_company_id_and_stock"
    t.index ["deleted_at"], name: "index_inventories_on_deleted_at"
  end

  create_table "inventory_ledgers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.uuid "item_id", null: false
    t.integer "movement_type", null: false
    t.integer "quantity", null: false
    t.uuid "sales_order_item_id"
    t.text "remarks"
    t.string "sync_id"
    t.datetime "synced_at"
    t.datetime "deleted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "created_at"], name: "index_inventory_ledgers_on_company_id_and_created_at"
    t.index ["company_id", "item_id"], name: "index_inventory_ledgers_on_company_id_and_item_id"
    t.index ["company_id", "movement_type"], name: "index_inventory_ledgers_on_company_id_and_movement_type"
    t.index ["deleted_at"], name: "index_inventory_ledgers_on_deleted_at"
    t.index ["sync_id"], name: "index_inventory_ledgers_on_sync_id", unique: true, where: "(sync_id IS NOT NULL)"
  end

  create_table "items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.uuid "category_id", null: false
    t.string "sku", null: false
    t.string "name", null: false
    t.text "description"
    t.decimal "price", precision: 15, scale: 2, null: false
    t.string "image_url"
    t.jsonb "variants", default: {}
    t.boolean "active", default: true, null: false
    t.boolean "track_inventory", default: true, null: false
    t.integer "sort_order", default: 0
    t.datetime "deleted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "active"], name: "index_items_on_company_id_and_active"
    t.index ["company_id", "category_id"], name: "index_items_on_company_id_and_category_id"
    t.index ["company_id", "name"], name: "index_items_on_company_id_and_name"
    t.index ["company_id", "sku"], name: "index_items_on_company_id_and_sku", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_items_on_deleted_at"
  end

  create_table "payment_methods", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.boolean "is_default", default: false, null: false
    t.integer "sort_order", default: 0
    t.datetime "deleted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "active"], name: "index_payment_methods_on_company_id_and_active"
    t.index ["company_id", "is_default"], name: "index_payment_methods_on_company_id_and_is_default"
    t.index ["company_id", "name"], name: "index_payment_methods_on_company_id_and_name", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_payment_methods_on_deleted_at"
  end

  create_table "sales_order_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "sales_order_id", null: false
    t.uuid "item_id", null: false
    t.decimal "price", precision: 15, scale: 2, null: false
    t.integer "quantity", null: false
    t.decimal "tax_rate", precision: 5, scale: 4, default: "0.0"
    t.decimal "tax_amount", precision: 15, scale: 2, default: "0.0"
    t.string "sync_id"
    t.datetime "synced_at"
    t.datetime "deleted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_sales_order_items_on_deleted_at"
    t.index ["sync_id"], name: "index_sales_order_items_on_sync_id", unique: true, where: "(sync_id IS NOT NULL)"
  end

  create_table "sales_orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.string "order_no", null: false
    t.decimal "sub_total", precision: 15, scale: 2, null: false
    t.decimal "discount", precision: 15, scale: 2, default: "0.0"
    t.decimal "tax_rate", precision: 5, scale: 4, default: "0.0"
    t.decimal "tax_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "grand_total", precision: 15, scale: 2, null: false
    t.uuid "payment_method_id", null: false
    t.decimal "paid_amount", precision: 15, scale: 2, null: false
    t.decimal "change_amount", precision: 15, scale: 2, default: "0.0"
    t.integer "status", default: 0, null: false
    t.string "sync_id"
    t.datetime "synced_at"
    t.datetime "deleted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "created_at"], name: "index_sales_orders_on_company_id_and_created_at"
    t.index ["company_id", "order_no"], name: "index_sales_orders_on_company_id_and_order_no", unique: true, where: "(deleted_at IS NULL)"
    t.index ["company_id", "status"], name: "index_sales_orders_on_company_id_and_status"
    t.index ["deleted_at"], name: "index_sales_orders_on_deleted_at"
    t.index ["sync_id"], name: "index_sales_orders_on_sync_id", unique: true, where: "(sync_id IS NOT NULL)"
  end

  create_table "taxes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.string "name", null: false
    t.decimal "rate", precision: 5, scale: 4, null: false
    t.boolean "active", default: true, null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "deleted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "active"], name: "index_taxes_on_company_id_and_active"
    t.index ["company_id", "is_default"], name: "index_taxes_on_company_id_and_is_default"
    t.index ["company_id", "name"], name: "index_taxes_on_company_id_and_name", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_taxes_on_deleted_at"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "last_login_at"
    t.string "last_login_ip"
    t.datetime "deleted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "active"], name: "index_users_on_company_id_and_active"
    t.index ["company_id", "email"], name: "index_users_on_company_id_and_email", unique: true, where: "(deleted_at IS NULL)"
    t.index ["company_id", "role"], name: "index_users_on_company_id_and_role"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["last_login_at"], name: "index_users_on_last_login_at"
  end
end
