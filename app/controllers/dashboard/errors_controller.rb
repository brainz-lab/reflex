module Dashboard
  class ErrorsController < BaseController
    def index
      @errors = @project.error_groups

      # Text search (error_class, message, file_path)
      if params[:q].present?
        query = "%#{params[:q]}%"
        @errors = @errors.where(
          "error_class ILIKE ? OR message ILIKE ? OR file_path ILIKE ?",
          query, query, query
        )
      end

      # Advanced filters
      @errors = @errors.where(error_class: params[:error_class]) if params[:error_class].present?
      @errors = @errors.where(last_environment: params[:environment]) if params[:environment].present?

      # Status filter
      @errors = case params[:status]
      when "resolved" then @errors.resolved
      when "ignored" then @errors.ignored
      else @errors.unresolved
      end

      @errors = @errors.recent.limit(100)

      # Load errors into memory to avoid N+1 in view
      @errors = @errors.to_a
      @errors_count = @errors.size

      # For filter dropdowns - use single query with pluck for both columns
      dropdown_data = @project.error_groups.distinct.pluck(:error_class, :last_environment)
      @error_classes = dropdown_data.map(&:first).compact.uniq.sort
      @environments = dropdown_data.map(&:last).compact.uniq.sort

      # Stats - use single query with group_by for status counts
      status_counts = @project.error_groups.group(:status).count
      @stats = {
        unresolved: status_counts["unresolved"] || 0,
        resolved: status_counts["resolved"] || 0,
        events_today: @project.error_events.where("occurred_at >= ?", Time.current.beginning_of_day).count
      }
    end

    def show
      @error = @project.error_groups.find(params[:id])
      @events = @error.events.recent

      # Allow selecting a specific event
      if params[:event_id].present?
        @selected_event = @events.find_by(id: params[:event_id])
      end
      @selected_event ||= @events.first

      # Calculate position and navigation
      @event_ids = @events.pluck(:id)
      @current_index = @event_ids.index(@selected_event&.id) || 0
      @prev_event_id = @event_ids[@current_index - 1] if @current_index > 0
      @next_event_id = @event_ids[@current_index + 1] if @current_index < @event_ids.length - 1

      @events = @events.limit(20)
    end

    def resolve
      @error = @project.error_groups.find(params[:id])
      @error.resolve!
      ErrorsChannel.broadcast_error_resolved(@project, @error)
      redirect_to dashboard_project_error_path(@project, @error), notice: "Error marked as resolved"
    end

    def ignore
      @error = @project.error_groups.find(params[:id])
      @error.ignore!
      ErrorsChannel.broadcast_error_ignored(@project, @error)
      redirect_to dashboard_project_errors_path(@project), notice: "Error ignored"
    end

    def unresolve
      @error = @project.error_groups.find(params[:id])
      @error.unresolve!
      ErrorsChannel.broadcast_error_unresolved(@project, @error)
      redirect_to dashboard_project_error_path(@project, @error), notice: "Error marked as unresolved"
    end
  end
end
