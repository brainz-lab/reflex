module Dashboard
  class BaseController < ApplicationController
    layout 'dashboard'

    before_action :authenticate!

    helper_method :current_project

    private

    def authenticate!
      raw_key = extract_api_key
      return redirect_to_auth if raw_key.blank?

      key_info = PlatformClient.validate_key(raw_key)

      unless key_info[:valid]
        session.delete(:api_key)
        return redirect_to_auth
      end

      # Store in session for subsequent requests
      session[:api_key] = raw_key unless session[:api_key]

      @current_project = Project.find_or_create_for_platform!(
        platform_project_id: key_info[:project_id],
        name: key_info[:project_name],
        environment: key_info[:environment] || 'live'
      )
    end

    def current_project
      @current_project
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
