module Dashboard
  class ErrorsController < BaseController
    def index
      @errors = current_project.error_groups

      @errors = case params[:status]
      when 'resolved' then @errors.resolved
      when 'ignored' then @errors.ignored
      else @errors.unresolved
      end

      @errors = @errors.recent.limit(100)

      @stats = {
        unresolved: current_project.error_groups.unresolved.count,
        resolved: current_project.error_groups.resolved.count,
        events_today: current_project.error_events.where('occurred_at >= ?', Time.current.beginning_of_day).count
      }
    end

    def show
      @error = current_project.error_groups.find(params[:id])
      @latest_event = @error.events.recent.first
      @events = @error.events.recent.limit(20)
    end

    def resolve
      @error = current_project.error_groups.find(params[:id])
      @error.resolve!
      redirect_to dashboard_error_path(@error), notice: 'Error marked as resolved'
    end

    def ignore
      @error = current_project.error_groups.find(params[:id])
      @error.ignore!
      redirect_to dashboard_errors_path, notice: 'Error ignored'
    end

    def unresolve
      @error = current_project.error_groups.find(params[:id])
      @error.unresolve!
      redirect_to dashboard_error_path(@error), notice: 'Error marked as unresolved'
    end
  end
end
