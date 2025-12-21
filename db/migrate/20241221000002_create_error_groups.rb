class CreateErrorGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :error_groups, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      # Identification
      t.string :fingerprint, null: false          # Unique hash for grouping
      t.string :error_class, null: false          # NoMethodError, RuntimeError, etc.
      t.text :message                             # Error message (first occurrence)

      # Location
      t.string :file_path                         # app/controllers/users_controller.rb
      t.integer :line_number
      t.string :function_name                     # create, update, etc.
      t.string :controller                        # UsersController
      t.string :action                            # create

      # Status
      t.string :status, default: 'unresolved'     # unresolved, resolved, ignored, muted
      t.datetime :resolved_at
      t.string :resolved_by                       # user_id who resolved

      # Counts & timing
      t.bigint :event_count, default: 0
      t.datetime :first_seen_at
      t.datetime :last_seen_at

      # Context
      t.string :last_commit                       # Git commit when last seen
      t.string :last_environment                  # production, staging

      # Notifications
      t.boolean :notifications_enabled, default: true
      t.datetime :last_notified_at

      t.timestamps

      t.index [:project_id, :fingerprint], unique: true
      t.index [:project_id, :status]
      t.index [:project_id, :last_seen_at]
      t.index [:project_id, :error_class]
      t.index :fingerprint
    end
  end
end
