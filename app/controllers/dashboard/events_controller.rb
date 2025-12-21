module Dashboard
  class EventsController < BaseController
    before_action :set_error

    def index
      @events = @error.events.recent.limit(100)
    end

    def show
      @event = @error.events.find(params[:id])
    end

    private

    def set_error
      @error = current_project.error_groups.find(params[:error_id])
    end
  end
end
