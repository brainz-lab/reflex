module Dashboard
  class DevToolsController < ApplicationController
    layout "dashboard"
    before_action :ensure_development!

    def show
      @stats = {
        projects: Project.count,
        error_groups: ErrorGroup.count,
        error_events: ErrorEvent.count
      }
    end

    def clean_errors
      counts = {
        error_events: ErrorEvent.delete_all,
        error_groups: ErrorGroup.delete_all
      }

      redirect_to dashboard_dev_tools_path, notice: "Cleaned #{counts[:error_groups]} error groups, #{counts[:error_events]} events"
    end

    def clean_all
      counts = {
        error_events: ErrorEvent.delete_all,
        error_groups: ErrorGroup.delete_all
      }

      redirect_to dashboard_dev_tools_path, notice: "Cleaned all data: #{counts.map { |k, v| "#{v} #{k}" }.join(', ')}"
    end

    private

    def ensure_development!
      unless Rails.env.development?
        redirect_to dashboard_root_path, alert: "Dev tools only available in development"
      end
    end
  end
end
