# frozen_string_literal: true

module Mcp
  module Tools
    class ReflexEvents < Base
      DESCRIPTION = "Get all occurrences (events) for a specific error."

      SCHEMA = {
        type: "object",
        properties: {
          error_id: { type: "string", description: "Error group ID" },
          limit: { type: "integer", description: "Max events to return (default: 20)" }
        },
        required: ["error_id"]
      }.freeze

      def call(args)
        error = @project.error_groups.find(args[:error_id])
        limit = [args[:limit] || 20, 100].min
        events = error.events.recent.limit(limit)

        {
          error_id: error.id,
          error_class: error.error_class,
          total_count: error.event_count,
          events: events.map { |e| format_event(e) }
        }
      rescue ActiveRecord::RecordNotFound
        { error: "Error not found" }
      end
    end
  end
end
