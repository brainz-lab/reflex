# frozen_string_literal: true

module Api
  module V1
    # Receives browser errors from brainzlab-js SDK
    class BrowserController < BaseController
      skip_before_action :authenticate!, only: [:preflight, :create]
      before_action :set_cors_headers
      before_action :find_project_from_token, only: [:create]
      before_action :validate_origin!, only: [:create]

      # OPTIONS /api/v1/browser (CORS preflight)
      def preflight
        head :ok
      end

      # POST /api/v1/browser
      # Receives browser error events from brainzlab-js SDK
      def create
        events = params[:events] || []
        context = params[:context] || {}
        accepted = 0

        unless @project
          render json: { error: "Project not found" }, status: :not_found
          return
        end

        events.each do |event|
          next unless event[:type] == "error"

          # Convert browser error to Reflex error format
          error_data = build_error_data(event, context)
          process_browser_error(error_data)
          accepted += 1
        end

        render json: {
          status: "ok",
          session_id: request.headers["X-BrainzLab-Session"],
          accepted: accepted
        }
      rescue StandardError => e
        Rails.logger.error("[BrowserController] Error: #{e.message}")
        render json: { error: "Failed to process events" }, status: :unprocessable_entity
      end

      private

      def build_error_data(event, context)
        error_data = event[:data] || {}
        trace_ctx = extract_trace_context

        error_context = {
          source: "browser",
          session_id: event[:sessionId],
          browser_url: event[:url],
          filename: error_data[:filename],
          lineno: error_data[:lineno],
          colno: error_data[:colno]
        }

        # Include trace context for correlation with server-side traces
        if trace_ctx
          error_context[:trace_id] = trace_ctx[:trace_id]
          error_context[:parent_span_id] = trace_ctx[:parent_span_id] || trace_ctx[:span_id]
        end

        # Also include trace info from event itself if present
        if event[:traceId]
          error_context[:trace_id] ||= event[:traceId]
          error_context[:browser_span_id] = event[:spanId]
          error_context[:parent_span_id] ||= event[:parentSpanId]
        end

        {
          error_class: error_data[:name] || "BrowserError",
          message: error_data[:message] || "Unknown browser error",
          backtrace: parse_browser_stack(error_data[:stack]),
          environment: context[:environment] || "production",
          commit: context[:release],
          request: {
            method: "GET",
            path: event[:url],
            user_agent: event[:userAgent]
          },
          context: error_context,
          tags: {
            source: "brainzlab-js"
          },
          timestamp: event[:timestamp]
        }
      end

      def parse_browser_stack(stack_string)
        return [] unless stack_string.is_a?(String)

        stack_string.split("\n").map(&:strip).reject(&:empty?)
      end

      def process_browser_error(error_data)
        # Use the existing error processing pipeline
        ErrorProcessor.new(project: @project, payload: error_data).process!
      end

      def find_project_from_token
        token = extract_browser_token
        return unless token

        # Prefer ingest_key for browser access (write-only, safe for browser exposure)
        if token.start_with?("rfx_ingest_")
          @project = Project.find_by("settings->>'ingest_key' = ?", token)
        elsif token.start_with?("rfx_api_")
          # Accept api_key but log warning - should use ingest_key for browser
          @project = Project.find_by("settings->>'api_key' = ?", token)
          Rails.logger.warn("[BrowserController] API key used for browser endpoint - consider using ingest_key")
        elsif token.start_with?("rfx_")
          # Legacy key format - try both
          @project = Project.find_by("settings->>'ingest_key' = ?", token) ||
                     Project.find_by("settings->>'api_key' = ?", token)
        else
          # Try to find by project_id from context
          project_id = params.dig(:context, :projectId)
          @project = Project.find_by(platform_project_id: project_id) if project_id
        end
      end

      def validate_origin!
        return unless @project

        # Skip validation in development
        return if Rails.env.development?

        # Skip validation for localhost origins
        origin = request.headers["Origin"]
        return if origin_is_localhost?(origin)

        # Validate against allowed_origins
        unless origin_allowed?(origin)
          render json: { error: "Origin not allowed" }, status: :forbidden
        end
      end

      def origin_allowed?(origin)
        allowed = @project.settings&.dig("allowed_origins")
        return true if allowed.blank? # No restriction if empty
        allowed.include?(origin)
      end

      def origin_is_localhost?(origin)
        return false if origin.blank?
        uri = URI.parse(origin)
        uri.host == "localhost" || uri.host == "127.0.0.1" || uri.host&.end_with?(".localhost")
      rescue URI::InvalidURIError
        false
      end

      def extract_browser_token
        auth_header = request.headers["Authorization"]
        return auth_header.sub(/^Bearer\s+/, "") if auth_header&.start_with?("Bearer ")
        request.headers["X-API-Key"]
      end

      def set_cors_headers
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-API-Key, X-BrainzLab-Session, traceparent, tracestate"
        response.headers["Access-Control-Max-Age"] = "86400"
      end

      # Extract trace context from request (W3C Trace Context format or body)
      def extract_trace_context
        # Try traceparent header first (W3C Trace Context)
        traceparent = request.headers["traceparent"] || request.headers["HTTP_TRACEPARENT"]
        if traceparent
          parts = traceparent.split("-")
          if parts.length >= 4
            return {
              trace_id: parts[1],
              span_id: parts[2],
              sampled: (parts[3].to_i(16) & 0x01) == 1
            }
          end
        end

        # Fallback to body context
        context = params[:context] || {}
        if context[:traceId]
          return {
            trace_id: context[:traceId],
            parent_span_id: context[:parentSpanId],
            sampled: true
          }
        end

        nil
      end
    end
  end
end
