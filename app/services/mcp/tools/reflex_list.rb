module Mcp
  module Tools
    class ReflexList < Base
      DESCRIPTION = "List errors. Can filter by status (unresolved, resolved, ignored) " \
        "and sort by recent or frequent."

      SCHEMA = {
        type: "object",
        properties: {
          status: {
            type: "string",
            enum: ["unresolved", "resolved", "ignored", "all"],
            default: "unresolved",
            description: "Filter by status"
          },
          sort: {
            type: "string",
            enum: ["recent", "frequent"],
            default: "recent",
            description: "Sort order"
          },
          limit: { type: "integer", default: 20, description: "Max results" }
        }
      }.freeze

      def call(args)
        errors = @project.error_groups

        errors = case args[:status]
        when 'all' then errors
        when 'resolved' then errors.resolved
        when 'ignored' then errors.ignored
        else errors.unresolved
        end

        errors = args[:sort] == 'frequent' ? errors.frequent : errors.recent
        errors = errors.limit(args[:limit] || 20)

        {
          errors: errors.map { |e| format_error(e) },
          count: errors.size
        }
      end
    end
  end
end
