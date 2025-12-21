class CreateErrorEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :error_events, id: :uuid do |t|
      t.references :error_group, type: :uuid, null: false, foreign_key: true
      t.references :project, type: :uuid, null: false, foreign_key: true

      # Error details
      t.string :error_class, null: false
      t.text :message
      t.jsonb :backtrace, default: []             # Array of stack frames

      # Context
      t.string :environment                       # production, staging
      t.string :commit                            # Git SHA
      t.string :branch                            # Git branch
      t.string :release                           # Release/version tag
      t.string :server_name                       # Hostname

      # Request context (if web request)
      t.string :request_id
      t.string :request_method                    # GET, POST, etc.
      t.string :request_url
      t.string :request_path
      t.jsonb :request_params, default: {}        # Sanitized params
      t.jsonb :request_headers, default: {}       # Selected headers

      # User context
      t.string :user_id
      t.string :user_email
      t.jsonb :user_data, default: {}             # Additional user info

      # Additional context
      t.jsonb :context, default: {}               # Custom context from SDK
      t.jsonb :tags, default: {}                  # Tags for filtering
      t.jsonb :extra, default: {}                 # Any extra data

      # Breadcrumbs (events leading up to error)
      t.jsonb :breadcrumbs, default: []

      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false

      t.index [:project_id, :occurred_at]
      t.index [:error_group_id, :occurred_at]
      t.index :request_id
      t.index :user_id
      t.index :commit
    end

    # JSONB indexes for querying
    execute "CREATE INDEX index_error_events_on_tags ON error_events USING GIN (tags jsonb_path_ops);"
    execute "CREATE INDEX index_error_events_on_context ON error_events USING GIN (context jsonb_path_ops);"
  end
end
