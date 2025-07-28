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

ActiveRecord::Schema[8.0].define(version: 2025_07_27_223935) do
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

  create_table "permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.string "name", null: false
    t.string "resource", null: false
    t.string "action", null: false
    t.text "description"
    t.boolean "system_permission", default: false, null: false
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_permissions_on_company_id_and_name", unique: true
    t.index ["company_id", "resource", "action"], name: "index_permissions_on_company_id_and_resource_and_action"
    t.index ["company_id"], name: "index_permissions_on_company_id"
    t.index ["deleted_at"], name: "index_permissions_on_deleted_at"
    t.index ["system_permission"], name: "index_permissions_on_system_permission"
  end

  create_table "price_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.uuid "item_id", null: false
    t.decimal "old_price", precision: 15, scale: 2, null: false
    t.decimal "new_price", precision: 15, scale: 2, null: false
    t.datetime "effective_date", null: false
    t.text "reason"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "effective_date"], name: "index_price_histories_on_company_id_and_effective_date"
    t.index ["company_id", "item_id"], name: "index_price_histories_on_company_id_and_item_id"
    t.index ["company_id"], name: "index_price_histories_on_company_id"
    t.index ["effective_date"], name: "index_price_histories_on_effective_date"
    t.index ["item_id"], name: "index_price_histories_on_item_id"
  end

  create_table "refresh_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "company_id", null: false
    t.string "token_hash", null: false
    t.string "device_fingerprint"
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "user_id"], name: "index_refresh_tokens_on_company_id_and_user_id"
    t.index ["expires_at"], name: "index_refresh_tokens_on_expires_at"
    t.index ["revoked_at"], name: "index_refresh_tokens_on_revoked_at"
    t.index ["token_hash"], name: "index_refresh_tokens_on_token_hash", unique: true
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

  create_table "stock_alerts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.uuid "item_id", null: false
    t.integer "alert_type", default: 0, null: false
    t.integer "threshold_value", default: 0, null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "last_alerted_at"
    t.uuid "created_by"
    t.uuid "updated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_type", "enabled"], name: "index_stock_alerts_on_alert_type_and_enabled"
    t.index ["company_id", "enabled"], name: "index_stock_alerts_on_company_id_and_enabled"
    t.index ["company_id", "item_id"], name: "index_stock_alerts_on_company_id_and_item_id", unique: true
    t.index ["company_id"], name: "index_stock_alerts_on_company_id"
    t.index ["item_id"], name: "index_stock_alerts_on_item_id"
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

  create_table "user_actions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.uuid "user_id"
    t.uuid "user_session_id"
    t.string "action", null: false
    t.string "resource_type", null: false
    t.string "resource_id"
    t.json "details", default: {}
    t.string "ip_address", null: false
    t.text "user_agent"
    t.boolean "success", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "success"], name: "index_user_actions_on_action_and_success"
    t.index ["action"], name: "index_user_actions_on_action"
    t.index ["company_id"], name: "index_user_actions_on_company_id"
    t.index ["resource_type", "resource_id"], name: "index_user_actions_on_resource_type_and_resource_id"
    t.index ["success"], name: "index_user_actions_on_success"
    t.index ["user_id", "created_at"], name: "index_user_actions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_user_actions_on_user_id"
    t.index ["user_session_id", "created_at"], name: "index_user_actions_on_user_session_id_and_created_at"
    t.index ["user_session_id"], name: "index_user_actions_on_user_session_id"
  end

  create_table "user_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "permission_id", null: false
    t.uuid "granted_by"
    t.datetime "granted_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["granted_by"], name: "index_user_permissions_on_granted_by"
    t.index ["permission_id"], name: "index_user_permissions_on_permission_id"
    t.index ["user_id", "permission_id"], name: "index_user_permissions_on_user_id_and_permission_id", unique: true
    t.index ["user_id"], name: "index_user_permissions_on_user_id"
  end

  create_table "user_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.uuid "user_id", null: false
    t.string "session_token", null: false
    t.string "device_fingerprint", null: false
    t.string "ip_address", null: false
    t.text "user_agent"
    t.datetime "last_activity_at"
    t.datetime "expired_at"
    t.datetime "logged_out_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_user_sessions_on_company_id"
    t.index ["expired_at"], name: "index_user_sessions_on_expired_at"
    t.index ["last_activity_at"], name: "index_user_sessions_on_last_activity_at"
    t.index ["logged_out_at"], name: "index_user_sessions_on_logged_out_at"
    t.index ["session_token"], name: "index_user_sessions_on_session_token", unique: true
    t.index ["user_id", "device_fingerprint"], name: "index_user_sessions_on_user_id_and_device_fingerprint"
    t.index ["user_id", "expired_at", "logged_out_at"], name: "index_user_sessions_active"
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
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

  add_foreign_key "permissions", "companies"
  add_foreign_key "price_histories", "companies"
  add_foreign_key "price_histories", "items"
  add_foreign_key "stock_alerts", "companies"
  add_foreign_key "stock_alerts", "items"
  add_foreign_key "user_actions", "companies"
  add_foreign_key "user_actions", "user_sessions"
  add_foreign_key "user_actions", "users"
  add_foreign_key "user_permissions", "permissions"
  add_foreign_key "user_permissions", "users"
  add_foreign_key "user_sessions", "companies"
  add_foreign_key "user_sessions", "users"
end
