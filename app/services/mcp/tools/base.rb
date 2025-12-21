module Mcp
  module Tools
    class Base
      def initialize(project)
        @project = project
      end

      def call(args)
        raise NotImplementedError
      end

      protected

      def format_error(error)
        {
          id: error.id,
          error_class: error.error_class,
          message: error.short_message,
          location: error.location,
          status: error.status,
          event_count: error.event_count,
          first_seen: error.first_seen_at,
          last_seen: error.last_seen_at,
          last_commit: error.last_commit
        }
      end

      def format_event(event)
        {
          id: event.id,
          occurred_at: event.occurred_at,
          environment: event.environment,
          commit: event.commit,
          user_id: event.user_id,
          request_path: event.request_path,
          backtrace: event.app_backtrace.first(5)
        }
      end

      def parse_since(value)
        case value
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        when /^(\d+)w$/ then $1.to_i.weeks.ago
        else 24.hours.ago
        end
      end
    end
  end
end
