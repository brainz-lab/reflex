module Api
  module V1
    class EventsController < BaseController
      # POST /api/v1/errors
      def create
        result = ErrorProcessor.new(
          project: current_project,
          payload: error_params.to_h
        ).process!

        track_usage!(1)

        render json: {
          id: result[:event].id,
          error_group_id: result[:error_group].id,
          fingerprint: result[:error_group].fingerprint
        }, status: :created
      end

      # POST /api/v1/errors/batch
      def batch
        errors = params[:errors] || params[:_json] || []
        results = []

        errors.each do |error_payload|
          result = ErrorProcessor.new(
            project: current_project,
            payload: error_payload.to_unsafe_h
          ).process!

          results << {
            id: result[:event].id,
            error_group_id: result[:error_group].id
          }
        end

        track_usage!(results.size)

        render json: { processed: results.size, results: results }, status: :created
      end

      # POST /api/v1/messages
      def create_message
        payload = message_params.to_h.merge(
          error_class: "Message",
          message: params[:message]
        )

        result = ErrorProcessor.new(
          project: current_project,
          payload: payload
        ).process!

        track_usage!(1)

        render json: {
          id: result[:event].id,
          error_group_id: result[:error_group].id,
          fingerprint: result[:error_group].fingerprint
        }, status: :created
      end

      private

      def error_params
        params.permit(
          :error_class, :message, :timestamp, :environment, :commit, :branch,
          :release, :server_name, :host, :request_id,
          exception: [ :class, :message, backtrace: [] ],
          backtrace: [],
          request: [ :id, :method, :url, :path, :controller, :action, params: {}, headers: {} ],
          user: [ :id, :email, :name ],
          context: {},
          tags: {},
          extra: {},
          breadcrumbs: []
        )
      end

      def message_params
        params.permit(
          :message, :level, :timestamp, :environment, :commit, :branch,
          :release, :server_name, :host, :request_id,
          request: [ :id, :method, :url, :path, :controller, :action, params: {}, headers: {} ],
          user: [ :id, :email, :name ],
          context: {},
          tags: {},
          extra: {},
          breadcrumbs: []
        )
      end
    end
  end
end
