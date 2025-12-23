# frozen_string_literal: true

# Self-error tracking for Reflex
# Uses direct database inserts to avoid HTTP infinite loops
# Uses SDK for Recall logging
#
# Set BRAINZLAB_SDK_ENABLED=false to disable SDK initialization
# Useful for running migrations before SDK is ready
#
# Set BRAINZLAB_LOCAL_DEV=true to enable cross-service integrations
# (Recall logging, Pulse APM). Off by default to avoid double monitoring.

# Skip during asset precompilation or when explicitly disabled
return if ENV["BRAINZLAB_SDK_ENABLED"] == "false"
return if ENV["SECRET_KEY_BASE_DUMMY"].present?

# Cross-service integrations only enabled when BRAINZLAB_LOCAL_DEV=true
local_dev_mode = ENV["BRAINZLAB_LOCAL_DEV"] == "true"

# Configure BrainzLab SDK
BrainzLab.configure do |config|
  # App name for auto-provisioning Recall project
  config.app_name = "reflex"

  # Recall logging configuration (only in local dev mode)
  config.recall_enabled = local_dev_mode
  config.recall_url = ENV.fetch("RECALL_URL", "http://recall.localhost")
  config.recall_master_key = ENV["RECALL_MASTER_KEY"]
  config.recall_min_level = Rails.env.production? ? :info : :debug

  # Enable Pulse APM (only in local dev mode)
  config.pulse_enabled = local_dev_mode
  config.pulse_url = ENV.fetch("PULSE_URL", "http://pulse.localhost")
  config.pulse_master_key = ENV["PULSE_MASTER_KEY"]

  # Service identification
  config.service = "reflex"
  config.environment = Rails.env

  # Disable SDK Reflex error tracking (we use direct DB inserts)
  config.reflex_enabled = false
end

# Middleware to capture request context for self-tracking
class ReflexSelfTrackMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    Thread.current[:reflex_request_id] = request.request_id
    Thread.current[:reflex_request_method] = request.request_method
    Thread.current[:reflex_request_path] = request.path
    Thread.current[:reflex_request_url] = request.url
    Thread.current[:reflex_request_params] = filter_params(request.params.to_h)
    @app.call(env)
  ensure
    Thread.current[:reflex_request_id] = nil
    Thread.current[:reflex_request_method] = nil
    Thread.current[:reflex_request_path] = nil
    Thread.current[:reflex_request_url] = nil
    Thread.current[:reflex_request_params] = nil
  end

  private

  def filter_params(params)
    filtered = params.dup
    %w[password password_confirmation token api_key secret].each do |key|
      filtered.delete(key)
      filtered.delete(key.to_sym)
    end
    filtered.except("controller", "action")
  end
end

Rails.application.config.middleware.insert_after ActionDispatch::RequestId, ReflexSelfTrackMiddleware

Rails.application.config.after_initialize do
  # Provision Recall and Pulse projects only in local dev mode
  if local_dev_mode
    BrainzLab::Recall.ensure_provisioned!
    BrainzLab::Pulse.ensure_provisioned!
  end

  # Find or create the reflex project for self-tracking
  project = Project.find_or_create_by!(name: "reflex") do |p|
    p.platform_project_id = "rfx_self_#{SecureRandom.hex(8)}"
    p.environment = Rails.env
  end

  # Generate API key if not present
  unless project.settings["api_key"]
    project.settings["api_key"] = "rfx_self_#{SecureRandom.hex(24)}"
    project.save!
  end

  Rails.logger.info "[Reflex] Self-error tracking enabled for project: #{project.id}"
  Rails.logger.info "[Reflex] Local dev mode: #{local_dev_mode ? 'enabled' : 'disabled'}"
  Rails.logger.info "[Reflex] Recall logging: #{BrainzLab.configuration.recall_enabled ? 'enabled' : 'disabled'}"
  Rails.logger.info "[Reflex] Pulse APM: #{BrainzLab.configuration.pulse_enabled ? 'enabled' : 'disabled'}"

  # Subscribe to request completion events for Recall logging
  if local_dev_mode && BrainzLab.configuration.recall_enabled
    ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      payload = event.payload

      # Skip ingest endpoints to reduce noise
      next if payload[:controller]&.include?("EventsController")
      next if payload[:path]&.start_with?("/api/v1/errors")

      BrainzLab::Recall.info("#{payload[:method]} #{payload[:path]}",
        controller: payload[:controller],
        action: payload[:action],
        status: payload[:status],
        duration_ms: event.duration.round(1),
        view_ms: payload[:view_runtime]&.round(1),
        db_ms: payload[:db_runtime]&.round(1),
        format: payload[:format],
        params: payload[:params].except("controller", "action").to_h
      )
    end
  end

  # ============================================================================
  # Self-Error Tracking via Direct Database Inserts
  # ============================================================================

  # Excluded exceptions (routing errors, etc.)
  excluded_exceptions = [
    "ActionController::RoutingError",
    "ActionController::InvalidAuthenticityToken",
    "ActionController::UnknownFormat",
    "ActiveRecord::RecordNotFound"
  ]

  # Helper to capture errors directly to database
  capture_error = ->(exception, context = {}) do
    return if excluded_exceptions.include?(exception.class.name)

    begin
      # Build payload similar to SDK
      backtrace = (exception.backtrace || []).first(30).map do |line|
        if line =~ /\A(.+):(\d+):in `(.+)'\z/
          {
            "file" => $1,
            "line" => $2.to_i,
            "function" => $3,
            "in_app" => !$1.include?("gems/")
          }
        else
          { "raw" => line }
        end
      end

      payload = {
        "error_class" => exception.class.name,
        "message" => exception.message,
        "backtrace" => backtrace,
        "timestamp" => Time.current.iso8601(3),
        "environment" => Rails.env,
        "commit" => ENV["GIT_COMMIT"] || `git rev-parse HEAD 2>/dev/null`.strip.presence,
        "branch" => ENV["GIT_BRANCH"] || `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip.presence,
        "server_name" => Socket.gethostname,
        "request_id" => Thread.current[:reflex_request_id],
        "request" => {
          "method" => Thread.current[:reflex_request_method],
          "path" => Thread.current[:reflex_request_path],
          "url" => Thread.current[:reflex_request_url],
          "params" => Thread.current[:reflex_request_params]
        }.compact
      }.merge(context)

      # Use ErrorProcessor to process the error
      ErrorProcessor.new(project: project, payload: payload).process!

      Rails.logger.info "[Reflex] Self-tracked error: #{exception.class} - #{exception.message}"
    rescue StandardError => e
      Rails.logger.error "[Reflex] Self-tracking failed: #{e.message}"
    end
  end

  # Hook into Rails 7+ error reporting
  if defined?(::Rails.error) && ::Rails.error.respond_to?(:subscribe)
    ::Rails.error.subscribe(Class.new do
      define_method(:report) do |error, handled:, severity:, context: {}, source: nil|
        capture_error.call(error, {
          "handled" => handled,
          "severity" => severity.to_s,
          "source" => source,
          "extra" => context
        })
      end
    end.new)
  end

  # Subscribe to job errors
  ActiveSupport::Notifications.subscribe("discard.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]
    error = event.payload[:error]

    next unless error

    capture_error.call(error, {
      "tags" => { "type" => "background_job" },
      "extra" => {
        "job_class" => job.class.name,
        "job_id" => job.job_id,
        "queue_name" => job.queue_name,
        "executions" => job.executions
      }
    })
  end

  # Subscribe to retry stopped (after all retries exhausted)
  ActiveSupport::Notifications.subscribe("retry_stopped.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]
    error = event.payload[:error]

    next unless error

    capture_error.call(error, {
      "tags" => { "type" => "background_job", "retry_exhausted" => "true" },
      "extra" => {
        "job_class" => job.class.name,
        "job_id" => job.job_id,
        "queue_name" => job.queue_name,
        "executions" => job.executions
      }
    })
  end
end
