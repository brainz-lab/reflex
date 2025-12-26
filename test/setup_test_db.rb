ENV["RAILS_ENV"] = "test"
ENV["BRAINZLAB_SDK_ENABLED"] = "false"

require_relative "../config/environment"

ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

# Try to create timescaledb extension, but don't fail if not available
begin
  ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS timescaledb")
  puts "TimescaleDB extension enabled"
rescue StandardError => e
  puts "TimescaleDB not available (this is OK for testing): #{e.message}"
end

ActiveRecord::Migration.verbose = true
ActiveRecord::Tasks::DatabaseTasks.migrate

puts "Test database setup complete!"
