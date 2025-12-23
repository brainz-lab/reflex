class ConvertErrorEventsToHypertable < ActiveRecord::Migration[8.0]
  def up
    # TimescaleDB requires the time column to be part of any unique index/primary key
    # We need to drop the primary key and recreate as composite key

    # Remove existing primary key
    execute "ALTER TABLE error_events DROP CONSTRAINT error_events_pkey;"

    # Create composite primary key with occurred_at
    execute "ALTER TABLE error_events ADD PRIMARY KEY (id, occurred_at);"

    # Convert to hypertable
    execute <<-SQL
      SELECT create_hypertable(
        'error_events',
        'occurred_at',
        chunk_time_interval => INTERVAL '1 day',
        migrate_data => true,
        if_not_exists => true
      );
    SQL

    # Enable compression
    execute <<-SQL
      ALTER TABLE error_events SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'project_id, error_group_id',
        timescaledb.compress_orderby = 'occurred_at DESC'
      );
    SQL

    # Compression policy
    execute "SELECT add_compression_policy('error_events', INTERVAL '7 days', if_not_exists => true);"

    # Retention policy
    execute "SELECT add_retention_policy('error_events', INTERVAL '90 days', if_not_exists => true);"
  end

  def down
    execute "SELECT remove_retention_policy('error_events', if_exists => true);"
    execute "SELECT remove_compression_policy('error_events', if_exists => true);"
    execute "ALTER TABLE error_events SET (timescaledb.compress = false);"
  end
end
