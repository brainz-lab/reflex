module Mcp
  module Tools
    class ReflexSearch < Base
      DESCRIPTION = "Search errors by class name, message, or other criteria."

      SCHEMA = {
        type: "object",
        properties: {
          query: { type: "string", description: "Search query" },
          error_class: { type: "string", description: "Filter by error class" },
          user_id: { type: "string", description: "Filter by user ID" },
          commit: { type: "string", description: "Filter by commit" },
          since: { type: "string", description: "Time period (1h, 24h, 7d)" }
        }
      }.freeze

      def call(args)
        errors = @project.error_groups

        if args[:query].present?
          errors = errors.where("error_class ILIKE ? OR message ILIKE ?",
            "%#{args[:query]}%", "%#{args[:query]}%")
        end

        errors = errors.where(error_class: args[:error_class]) if args[:error_class].present?

        if args[:since].present?
          since = parse_since(args[:since])
          errors = errors.where("last_seen_at >= ?", since)
        end

        # If filtering by user or commit, need to check events
        if args[:user_id].present? || args[:commit].present?
          event_scope = @project.error_events
          event_scope = event_scope.where(user_id: args[:user_id]) if args[:user_id].present?
          event_scope = event_scope.where(commit: args[:commit]) if args[:commit].present?

          error_ids = event_scope.distinct.pluck(:error_group_id)
          errors = errors.where(id: error_ids)
        end

        {
          errors: errors.recent.limit(20).map { |e|
            { id: e.id, error_class: e.error_class, message: e.short_message, event_count: e.event_count }
          },
          count: errors.count
        }
      end
    end
  end
end
