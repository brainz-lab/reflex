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
          errors = errors.where('last_seen_at >= ?', since) if since
        end

        errors = case params[:sort]
        when 'frequent' then errors.frequent
        when 'first_seen' then errors.order(first_seen_at: :desc)
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

        render json: { resolved: true, error: serialize_error(error) }
      end

      # POST /api/v1/errors/:id/ignore
      def ignore
        error = current_project.error_groups.find(params[:id])
        error.ignore!

        render json: { ignored: true, error: serialize_error(error) }
      end

      # POST /api/v1/errors/:id/unresolve
      def unresolve
        error = current_project.error_groups.find(params[:id])
        error.unresolve!

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

      private

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
