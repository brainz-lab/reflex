module Dashboard
  class BaseController < ApplicationController
    layout "dashboard"

    before_action :authenticate_via_sso!
    before_action :set_project

    helper_method :current_project

    private

    def authenticate_via_sso!
      # In development, allow bypass
      if Rails.env.development?
        # Use first project for testing, or create one
        project = Project.first
        session[:platform_project_id] ||= project&.platform_project_id || "dev_project"
        session[:platform_user_id] ||= "dev_user"
        return
      end

      unless session[:platform_project_id]
        redirect_to "#{platform_url}/auth/sso?product=reflex&return_to=#{CGI.escape(request.url)}", allow_other_host: true
      end
    end

    def set_project
      # For nested routes (errors, events), use :project_id
      # For member routes on projects (edit, setup, analytics), use :id
      project_id = params[:project_id] || (controller_name == "projects" ? params[:id] : nil)

      if project_id.present?
        @project = Project.find(project_id)

        # Skip authorization check in development
        return if Rails.env.development?

        # Verify the project matches the SSO session's project
        if session[:platform_project_id] != @project.platform_project_id
          redirect_to dashboard_root_path, alert: "Project access denied"
        end
      else
        # Find or create project for the SSO session
        @project = Project.find_or_create_for_platform!(
          platform_project_id: session[:platform_project_id] || "dev_project",
          name: session[:project_name] || "Development Project"
        )
      end
    end

    def current_project
      @project
    end

    def platform_url
      ENV["BRAINZLAB_PLATFORM_EXTERNAL_URL"] || ENV["BRAINZLAB_PLATFORM_URL"] || "https://platform.brainzlab.ai"
    end

    # Build SSO URL with optional project_id
    def sso_url_for_project(project_id)
      base_url = "#{platform_url}/auth/sso"
      params = { product: "reflex", return_to: dashboard_root_url }
      params[:project_id] = project_id if project_id.present?
      "#{base_url}?#{params.to_query}"
    end
    helper_method :sso_url_for_project
  end
end
