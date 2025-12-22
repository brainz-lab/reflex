# frozen_string_literal: true

module Api
  module V1
    class ProjectsController < ActionController::API
      before_action :authenticate_master_key!

      # POST /api/v1/projects/provision
      # Creates a new project or returns existing one
      # Used by SDK auto-provisioning
      def provision
        name = params[:name].to_s.strip
        return render json: { error: "Name is required" }, status: :bad_request if name.empty?

        # Generate a platform_project_id for standalone projects
        # In production, this would integrate with Platform
        platform_project_id = "rfx_#{SecureRandom.hex(8)}"

        project = Project.find_by(name: name) || Project.create!(
          platform_project_id: platform_project_id,
          name: name,
          environment: params[:environment] || "development"
        )

        # Generate API key for this project (stored in settings or separate table)
        api_key = project.settings["api_key"] ||= "rfx_#{SecureRandom.hex(24)}"
        project.save! if project.settings_changed?

        render json: {
          id: project.id,
          name: project.name,
          api_key: api_key,
          platform_project_id: project.platform_project_id
        }
      end

      # GET /api/v1/projects/lookup
      # Looks up a project by name
      def lookup
        project = Project.find_by(name: params[:name])

        if project
          render json: {
            id: project.id,
            name: project.name,
            api_key: project.settings["api_key"],
            platform_project_id: project.platform_project_id
          }
        else
          render json: { error: "Project not found" }, status: :not_found
        end
      end

      private

      def authenticate_master_key!
        key = request.headers["X-Master-Key"]
        expected = ENV["REFLEX_MASTER_KEY"]

        return if key.present? && expected.present? && ActiveSupport::SecurityUtils.secure_compare(key, expected)

        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
