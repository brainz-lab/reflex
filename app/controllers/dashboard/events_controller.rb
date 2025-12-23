module Dashboard
  class EventsController < BaseController
    before_action :set_error

    def index
      @events = @error.events.recent.limit(100)
    end

    def show
      @event = @error.events.find_by_composite_key(params[:id])
    end

    private

    def set_error
      @error = @project.error_groups.find(params[:error_id])
    end
  end
end
