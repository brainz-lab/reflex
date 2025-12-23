# Concern for finding records in TimescaleDB hypertables with composite primary keys
# The composite key format in URLs is: id_timestamp (e.g., "123_2025-12-23 20:53:17 UTC")
module HypertableFindable
  extend ActiveSupport::Concern

  class_methods do
    # Find a record by parsing a composite key string from URL params
    # @param composite_key [String] The composite key in format "id_timestamp"
    # @param time_column [Symbol] The name of the time column (default: :occurred_at)
    # @return [ActiveRecord::Base] The found record
    # @raise [ActiveRecord::RecordNotFound] If record not found
    def find_by_composite_key(composite_key, time_column: :occurred_at)
      id, time_str = parse_composite_key(composite_key)
      find_by!(id: id, time_column => time_str)
    end

    # Find a record by composite key within a scope
    def find_by_composite_key!(composite_key, time_column: :occurred_at)
      id, time_str = parse_composite_key(composite_key)
      find_by!(id: id, time_column => time_str)
    end

    private

    def parse_composite_key(composite_key)
      # Handle URL-decoded format: "123_2025-12-23 20:53:17 UTC"
      # The ID is everything before the first underscore followed by a date pattern
      match = composite_key.to_s.match(/\A(.+?)_(\d{4}-\d{2}-\d{2}.+)\z/)
      raise ActiveRecord::RecordNotFound, "Invalid composite key format" unless match

      id = match[1]
      time_str = match[2]

      [id, Time.zone.parse(time_str)]
    end
  end
end
