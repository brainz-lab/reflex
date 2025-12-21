module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate!
      before_action :check_feature_access!

      attr_reader :current_project, :key_info

      private

      def authenticate!
        raw_key = extract_api_key
        @key_info = PlatformClient.validate_key(raw_key)

        unless @key_info[:valid]
          render json: { error: 'Invalid API key' }, status: :unauthorized
          return
        end

        @current_project = Project.find_or_create_for_platform!(
          platform_project_id: @key_info[:project_id],
          name: @key_info[:project_name],
          environment: @key_info[:environment] || 'live'
        )
      end

      def check_feature_access!
        # In development, always allow access
        return if Rails.env.development?

        unless @key_info.dig(:features, :reflex)
          render json: {
            error: 'Reflex is not included in your plan',
            upgrade_url: 'https://brainzlab.ai/pricing'
          }, status: :forbidden
        end
      end

      def extract_api_key
        auth_header = request.headers['Authorization']
        return auth_header.sub(/^Bearer\s+/, '') if auth_header&.start_with?('Bearer ')
        request.headers['X-API-Key'] || params[:api_key]
      end

      def track_usage!(count = 1)
        return unless @key_info[:project_id]

        PlatformClient.track_usage(
          project_id: @key_info[:project_id],
          product: 'reflex',
          metric: 'errors',
          count: count
        )
      end
    end
  end
end
