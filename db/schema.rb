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

ActiveRecord::Schema[8.1].define(version: 2025_12_23_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "timescaledb"

  create_table "error_events", primary_key: ["id", "occurred_at"], force: :cascade do |t|
    t.jsonb "backtrace", default: []
    t.string "branch"
    t.jsonb "breadcrumbs", default: []
    t.string "commit"
    t.jsonb "context", default: {}
    t.datetime "created_at", null: false
    t.string "environment"
    t.string "error_class", null: false
    t.uuid "error_group_id", null: false
    t.jsonb "extra", default: {}
    t.uuid "id", default: -> { "gen_random_uuid()" }, null: false
    t.text "message"
    t.datetime "occurred_at", null: false
    t.uuid "project_id", null: false
    t.string "release"
    t.jsonb "request_headers", default: {}
    t.string "request_id"
    t.string "request_method"
    t.jsonb "request_params", default: {}
    t.string "request_path"
    t.string "request_url"
    t.string "server_name"
    t.jsonb "tags", default: {}
    t.jsonb "user_data", default: {}
    t.string "user_email"
    t.string "user_id"
    t.index ["commit"], name: "index_error_events_on_commit"
    t.index ["context"], name: "index_error_events_on_context", opclass: :jsonb_path_ops, using: :gin
    t.index ["error_group_id", "occurred_at"], name: "index_error_events_on_error_group_id_and_occurred_at"
    t.index ["error_group_id"], name: "index_error_events_on_error_group_id"
    t.index ["occurred_at"], name: "error_events_occurred_at_idx", order: :desc
    t.index ["project_id", "occurred_at"], name: "index_error_events_on_project_id_and_occurred_at"
    t.index ["project_id"], name: "index_error_events_on_project_id"
    t.index ["request_id"], name: "index_error_events_on_request_id"
    t.index ["tags"], name: "index_error_events_on_tags", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_error_events_on_user_id"
  end
