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

ActiveRecord::Schema[8.1].define(version: 2024_12_21_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "error_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
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
    t.index ["project_id", "occurred_at"], name: "index_error_events_on_project_id_and_occurred_at"
    t.index ["project_id"], name: "index_error_events_on_project_id"
    t.index ["request_id"], name: "index_error_events_on_request_id"
    t.index ["tags"], name: "index_error_events_on_tags", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_error_events_on_user_id"
  end

  create_table "error_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action"
    t.string "controller"
    t.datetime "created_at", null: false
    t.string "error_class", null: false
    t.bigint "event_count", default: 0
    t.string "file_path"
    t.string "fingerprint", null: false
    t.datetime "first_seen_at"
    t.string "function_name"
    t.string "last_commit"
    t.string "last_environment"
    t.datetime "last_notified_at"
    t.datetime "last_seen_at"
    t.integer "line_number"
    t.text "message"
    t.boolean "notifications_enabled", default: true
    t.uuid "project_id", null: false
    t.datetime "resolved_at"
    t.string "resolved_by"
    t.string "status", default: "unresolved"
    t.datetime "updated_at", null: false
    t.index ["fingerprint"], name: "index_error_groups_on_fingerprint"
    t.index ["project_id", "error_class"], name: "index_error_groups_on_project_id_and_error_class"
    t.index ["project_id", "fingerprint"], name: "index_error_groups_on_project_id_and_fingerprint", unique: true
    t.index ["project_id", "last_seen_at"], name: "index_error_groups_on_project_id_and_last_seen_at"
    t.index ["project_id", "status"], name: "index_error_groups_on_project_id_and_status"
    t.index ["project_id"], name: "index_error_groups_on_project_id"
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "environment", default: "live"
    t.bigint "error_count", default: 0
    t.bigint "event_count", default: 0
    t.string "name"
    t.string "platform_project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_project_id"], name: "index_projects_on_platform_project_id", unique: true
  end

  add_foreign_key "error_events", "error_groups"
  add_foreign_key "error_events", "projects"
  add_foreign_key "error_groups", "projects"
end
