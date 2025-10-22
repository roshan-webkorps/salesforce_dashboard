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

ActiveRecord::Schema[8.0].define(version: 2025_10_22_144339) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "salesforce_id", null: false
    t.string "name", null: false
    t.string "owner_salesforce_id"
    t.datetime "salesforce_created_date"
    t.decimal "arr", precision: 12, scale: 2
    t.string "status"
    t.string "industry"
    t.string "segment"
    t.integer "employee_count"
    t.string "app_type", default: "legacy", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "annual_revenue", precision: 12, scale: 2
    t.decimal "mrr", precision: 12, scale: 2
    t.decimal "amount_paid", precision: 12, scale: 2
    t.index ["app_type"], name: "index_accounts_on_app_type"
    t.index ["owner_salesforce_id"], name: "index_accounts_on_owner_salesforce_id"
    t.index ["salesforce_created_date"], name: "index_accounts_on_salesforce_created_date"
    t.index ["salesforce_id"], name: "index_accounts_on_salesforce_id", unique: true
    t.index ["status"], name: "index_accounts_on_status"
  end

  create_table "cases", force: :cascade do |t|
    t.string "salesforce_id", null: false
    t.string "account_salesforce_id"
    t.string "owner_salesforce_id"
    t.string "status"
    t.string "priority"
    t.string "case_type"
    t.datetime "salesforce_created_date"
    t.datetime "closed_date"
    t.string "app_type", default: "legacy", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_salesforce_id"], name: "index_cases_on_account_salesforce_id"
    t.index ["app_type"], name: "index_cases_on_app_type"
    t.index ["owner_salesforce_id"], name: "index_cases_on_owner_salesforce_id"
    t.index ["salesforce_created_date"], name: "index_cases_on_salesforce_created_date"
    t.index ["salesforce_id"], name: "index_cases_on_salesforce_id", unique: true
    t.index ["status"], name: "index_cases_on_status"
  end

  create_table "chat_prompt_histories", force: :cascade do |t|
    t.string "ip_address", null: false
    t.string "app_type", default: "legacy", null: false
    t.text "prompt", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ip_address", "prompt"], name: "index_chat_prompt_histories_on_ip_address_and_prompt", unique: true
  end

  create_table "leads", force: :cascade do |t|
    t.string "salesforce_id", null: false
    t.string "name", null: false
    t.string "company"
    t.string "email"
    t.string "status", null: false
    t.string "lead_source"
    t.string "owner_salesforce_id"
    t.datetime "salesforce_created_date"
    t.boolean "is_converted", default: false
    t.datetime "conversion_date"
    t.string "industry"
    t.string "app_type", default: "legacy", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_type"], name: "index_leads_on_app_type"
    t.index ["is_converted"], name: "index_leads_on_is_converted"
    t.index ["owner_salesforce_id"], name: "index_leads_on_owner_salesforce_id"
    t.index ["salesforce_created_date"], name: "index_leads_on_salesforce_created_date"
    t.index ["salesforce_id"], name: "index_leads_on_salesforce_id", unique: true
    t.index ["status"], name: "index_leads_on_status"
  end

  create_table "opportunities", force: :cascade do |t|
    t.string "salesforce_id", null: false
    t.string "name", null: false
    t.string "account_salesforce_id", null: false
    t.string "owner_salesforce_id", null: false
    t.string "stage_name", null: false
    t.decimal "amount", precision: 12, scale: 2
    t.date "close_date"
    t.datetime "salesforce_created_date"
    t.boolean "is_closed", default: false
    t.boolean "is_won", default: false
    t.string "opportunity_type"
    t.string "lead_source"
    t.string "app_type", default: "legacy", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "probability", precision: 5, scale: 2
    t.decimal "expected_revenue", precision: 12, scale: 2
    t.string "forecast_category"
    t.date "renewal_date"
    t.boolean "is_test_opportunity", default: false
    t.string "record_type_name"
    t.index ["account_salesforce_id"], name: "index_opportunities_on_account_salesforce_id"
    t.index ["app_type"], name: "index_opportunities_on_app_type"
    t.index ["expected_revenue"], name: "index_opportunities_on_expected_revenue"
    t.index ["is_closed", "is_won"], name: "index_opportunities_on_is_closed_and_is_won"
    t.index ["is_test_opportunity"], name: "index_opportunities_on_is_test_opportunity"
    t.index ["owner_salesforce_id"], name: "index_opportunities_on_owner_salesforce_id"
    t.index ["probability"], name: "index_opportunities_on_probability"
    t.index ["record_type_name"], name: "index_opportunities_on_record_type_name"
    t.index ["renewal_date"], name: "index_opportunities_on_renewal_date"
    t.index ["salesforce_created_date"], name: "index_opportunities_on_salesforce_created_date"
    t.index ["salesforce_id"], name: "index_opportunities_on_salesforce_id", unique: true
    t.index ["stage_name"], name: "index_opportunities_on_stage_name"
  end

  create_table "users", force: :cascade do |t|
    t.string "salesforce_id", null: false
    t.string "name", null: false
    t.string "email"
    t.string "role"
    t.boolean "is_active", default: true
    t.string "manager_salesforce_id"
    t.string "app_type", default: "legacy", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_type"], name: "index_users_on_app_type"
    t.index ["is_active"], name: "index_users_on_is_active"
    t.index ["role"], name: "index_users_on_role"
    t.index ["salesforce_id"], name: "index_users_on_salesforce_id", unique: true
  end
end
