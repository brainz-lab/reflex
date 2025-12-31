module Api
  module V1
    class ErrorsController < BaseController
      # GET /api/v1/errors
      def index
        errors = current_project.error_groups

        errors = errors.where(status: params[:status]) if params[:status].present?
        errors = errors.where(error_class: params[:error_class]) if params[:error_class].present?

        if params[:since].present?
          since = Time.parse(params[:since]) rescue nil
          errors = errors.where("last_seen_at >= ?", since) if since
        end

        errors = case params[:sort]
        when "frequent" then errors.frequent
        when "first_seen" then errors.order(first_seen_at: :desc)
        else errors.recent
        end

        errors = errors.limit(params[:limit] || 50)

        render json: {
          errors: errors.map { |e| serialize_error(e) }
        }
      end

      # GET /api/v1/errors/:id
      def show
        error = current_project.error_groups.find(params[:id])
        events = error.events.recent.limit(10)

        render json: {
          error: serialize_error(error),
          recent_events: events.map { |e| serialize_event(e) }
        }
      end

      # POST /api/v1/errors/:id/resolve
      def resolve
        error = current_project.error_groups.find(params[:id])
        error.resolve!
        ErrorsChannel.broadcast_error_resolved(current_project, error)

        render json: { resolved: true, error: serialize_error(error) }
      end

      # POST /api/v1/errors/:id/ignore
      def ignore
        error = current_project.error_groups.find(params[:id])
        error.ignore!
        ErrorsChannel.broadcast_error_ignored(current_project, error)

        render json: { ignored: true, error: serialize_error(error) }
      end

      # POST /api/v1/errors/:id/unresolve
      def unresolve
        error = current_project.error_groups.find(params[:id])
        error.unresolve!
        ErrorsChannel.broadcast_error_unresolved(current_project, error)

        render json: { unresolved: true, error: serialize_error(error) }
      end

      # GET /api/v1/errors/:id/events
      def events
        error = current_project.error_groups.find(params[:id])
        events = error.events.recent

        events = events.where(environment: params[:environment]) if params[:environment].present?
        events = events.limit(params[:limit] || 50)

        render json: {
          error_id: error.id,
          total_count: error.event_count,
          events: events.map { |e| serialize_event(e) }
        }
      end

      # Signal integration: Query errors with aggregation for alerting
      def query
        error_type = params[:error_type] || "all"
        aggregation = params[:aggregation] || "count"
        window = parse_window(params[:window] || "5m")
        query_filters = JSON.parse(params[:query] || "{}")

        scope = current_project.error_events.where("occurred_at >= ?", window.ago)

        # Filter by error type
        scope = scope.where(error_class: error_type) unless error_type == "all"

        # Apply additional query filters
        query_filters.each do |key, value|
          case key
          when "environment" then scope = scope.where(environment: value)
          when "status" then scope = scope.joins(:error_group).where(error_groups: { status: value })
          end
        end

        value = case aggregation
        when "count" then scope.count
        when "rate"
                  # Errors per minute
                  count = scope.count
                  minutes = (window / 60.0).to_f
                  minutes > 0 ? (count / minutes).round(2) : 0
        else
                  scope.count
        end

        render json: { value: value, error_type: error_type, window: params[:window] }
      end

      # Signal integration: Get baseline for anomaly detection
      def baseline
        error_type = params[:error_type] || "all"
        window = parse_window(params[:window] || "24h")

        scope = current_project.error_events.where("occurred_at >= ?", window.ago)
        scope = scope.where(error_class: error_type) unless error_type == "all"

        # Get hourly counts for the baseline window
        hourly_counts = scope.group("date_trunc('hour', occurred_at)")
                             .count
                             .values

        if hourly_counts.empty?
          render json: { mean: 0, stddev: 1 }
        else
          mean = hourly_counts.sum.to_f / hourly_counts.size
          variance = hourly_counts.map { |c| (c - mean)**2 }.sum / hourly_counts.size
          stddev = Math.sqrt(variance)

          render json: { mean: mean, stddev: [ stddev, 1 ].max }
        end
      end

      # Signal integration: Get last error for absence detection
      def last
        error_type = params[:error_type] || "all"
        query_filters = JSON.parse(params[:query] || "{}")

        scope = current_project.error_events
        scope = scope.where(error_class: error_type) unless error_type == "all"

        query_filters.each do |key, value|
          case key
          when "environment" then scope = scope.where(environment: value)
          end
        end

        last_event = scope.order(occurred_at: :desc).first

        if last_event
          render json: {
            timestamp: last_event.occurred_at.iso8601,
            value: 1,
            error_class: last_event.error_class,
            message: last_event.message
          }
        else
          render json: { timestamp: nil, value: nil }
        end
      end

      private

      def parse_window(window_str)
        match = window_str&.match(/^(\d+)(m|h|d)$/)
        return 5.minutes unless match

        value = match[1].to_i
        case match[2]
        when "m" then value.minutes
        when "h" then value.hours
        when "d" then value.days
        else 5.minutes
        end
      end

      def serialize_error(error)
        {
          id: error.id,
          error_class: error.error_class,
          message: error.message,
          short_message: error.short_message,
          location: error.location,
          file_path: error.file_path,
          line_number: error.line_number,
          function_name: error.function_name,
          controller: error.controller,
          action: error.action,
          status: error.status,
          event_count: error.event_count,
          first_seen_at: error.first_seen_at,
          last_seen_at: error.last_seen_at,
          last_commit: error.last_commit,
          last_environment: error.last_environment,
          resolved_at: error.resolved_at,
          resolved_by: error.resolved_by
        }
      end

      def serialize_event(event)
        {
          id: event.id,
          error_class: event.error_class,
          message: event.message,
          occurred_at: event.occurred_at,
          environment: event.environment,
          commit: event.commit,
          branch: event.branch,
          release: event.release,
          server_name: event.server_name,
          request_id: event.request_id,
          request_method: event.request_method,
          request_path: event.request_path,
          user_id: event.user_id,
          user_email: event.user_email,
          backtrace: event.app_backtrace.first(10),
          context: event.context,
          tags: event.tags
        }
      end
    end
  end
end
