module Dashboard
  class BaseController < ApplicationController
    layout 'dashboard'

    before_action :authenticate!
    before_action :set_project

    helper_method :current_project

    private

    def authenticate!
      raw_key = extract_api_key
      return redirect_to_auth if raw_key.blank?

      @api_key_info = PlatformClient.validate_key(raw_key)

      unless @api_key_info[:valid]
        session.delete(:api_key)
        return redirect_to_auth
      end

      # Store in session for subsequent requests
      session[:api_key] = raw_key unless session[:api_key]
    end

    def set_project
      return unless params[:project_id].present?

      @project = Project.find(params[:project_id])

      # Verify the project matches the API key's project
      unless @api_key_info[:project_id] == @project.platform_project_id
        redirect_to dashboard_root_path, alert: 'Project access denied'
      end
    end

    def current_project
      @project
    end

    def extract_api_key
      # Check session first, then params
      session[:api_key] || params[:api_key]
    end

    def redirect_to_auth
      if params[:api_key].present?
        # Store in session and redirect without api_key in URL
        session[:api_key] = params[:api_key]
        redirect_to request.path
      else
        # Show auth required page
        render 'dashboard/auth_required', status: :unauthorized
      end
    end
  end
end
