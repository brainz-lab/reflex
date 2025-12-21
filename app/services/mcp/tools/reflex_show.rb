module Mcp
  module Tools
    class ReflexShow < Base
      DESCRIPTION = "Get details of a specific error including recent occurrences and backtrace."

      SCHEMA = {
        type: "object",
        properties: {
          error_id: { type: "string", description: "Error group ID" }
        },
        required: ["error_id"]
      }.freeze

      def call(args)
        error = @project.error_groups.find(args[:error_id])
        events = error.events.recent.limit(5)

        {
          error: {
            id: error.id,
            error_class: error.error_class,
            message: error.message,
            location: error.location,
            file_path: error.file_path,
            line_number: error.line_number,
            function_name: error.function_name,
            status: error.status,
            event_count: error.event_count,
            first_seen: error.first_seen_at,
            last_seen: error.last_seen_at
          },
          recent_events: events.map { |e| format_event(e) }
        }
      rescue ActiveRecord::RecordNotFound
        { error: "Error not found" }
      end
    end
  end
end
