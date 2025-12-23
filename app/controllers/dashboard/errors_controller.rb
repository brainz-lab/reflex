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
      when 'resolved' then @errors.resolved
      when 'ignored' then @errors.ignored
      else @errors.unresolved
      end

      @errors = @errors.recent.limit(100)

      # For filter dropdowns
      @error_classes = @project.error_groups.distinct.pluck(:error_class).compact.sort
      @environments = @project.error_groups.distinct.pluck(:last_environment).compact.sort

      @stats = {
        unresolved: @project.error_groups.unresolved.count,
        resolved: @project.error_groups.resolved.count,
        events_today: @project.error_events.where('occurred_at >= ?', Time.current.beginning_of_day).count
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
      redirect_to dashboard_project_error_path(@project, @error), notice: 'Error marked as resolved'
    end

    def ignore
      @error = @project.error_groups.find(params[:id])
      @error.ignore!
      ErrorsChannel.broadcast_error_ignored(@project, @error)
      redirect_to dashboard_project_errors_path(@project), notice: 'Error ignored'
    end

    def unresolve
      @error = @project.error_groups.find(params[:id])
      @error.unresolve!
      ErrorsChannel.broadcast_error_unresolved(@project, @error)
      redirect_to dashboard_project_error_path(@project, @error), notice: 'Error marked as unresolved'
    end
  end
end
