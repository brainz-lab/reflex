module Mcp
  module Tools
    class ReflexStats < Base
      DESCRIPTION = "Get error statistics - counts by status, top errors, trends."

      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "24h", description: "Time period (1h, 24h, 7d)" }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || '24h')

        errors = @project.error_groups
        events = @project.error_events.where('occurred_at >= ?', since)

        {
          total_errors: errors.count,
          unresolved: errors.unresolved.count,
          resolved: errors.resolved.count,
          ignored: errors.ignored.count,

          events_in_period: events.count,

          top_errors: errors.unresolved.frequent.limit(5).map { |e|
            { error_class: e.error_class, message: e.short_message, count: e.event_count }
          },

          by_environment: events.group(:environment).count
        }
      end
    end
  end
end
