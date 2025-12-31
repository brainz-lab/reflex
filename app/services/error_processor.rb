class ErrorProcessor
  def initialize(project:, payload:)
    @project = project
    @payload = payload.deep_symbolize_keys
  end

  def process!
    # Generate fingerprint for grouping
    fingerprint = FingerprintGenerator.generate(@payload)

    # Find or create error group
    error_group = find_or_create_group(fingerprint)

    # Create event
    event = create_event(error_group)

    # Update group stats
    error_group.record_occurrence!(event)

    # Broadcast to dashboard
    broadcast_new_error(error_group, event)

    # Send notifications if needed
    maybe_notify(error_group, event)

    { error_group: error_group, event: event }
  end

  private

  def find_or_create_group(fingerprint)
    @project.error_groups.find_or_create_by!(fingerprint: fingerprint) do |group|
      group.error_class = @payload[:error_class] || @payload[:exception]&.dig(:class) || "UnknownError"
      group.message = @payload[:message] || @payload[:exception]&.dig(:message)
      group.file_path = extract_file_path
      group.line_number = extract_line_number
      group.function_name = extract_function_name
      group.controller = @payload.dig(:request, :controller)
      group.action = @payload.dig(:request, :action)
      group.first_seen_at = Time.current
      group.last_seen_at = Time.current
    end
  end

  def create_event(error_group)
    error_group.events.create!(
      project: @project,
      error_class: @payload[:error_class] || @payload[:exception]&.dig(:class) || "UnknownError",
      message: @payload[:message] || @payload[:exception]&.dig(:message),
      backtrace: normalize_backtrace(@payload[:backtrace] || @payload[:exception]&.dig(:backtrace) || []),

      environment: @payload[:environment],
      commit: @payload[:commit],
      branch: @payload[:branch],
      release: @payload[:release],
      server_name: @payload[:server_name] || @payload[:host],

      request_id: @payload.dig(:request, :id) || @payload[:request_id],
      request_method: @payload.dig(:request, :method),
      request_url: @payload.dig(:request, :url),
      request_path: @payload.dig(:request, :path),
      request_params: sanitize_params(@payload.dig(:request, :params) || {}),
      request_headers: @payload.dig(:request, :headers) || {},

      user_id: @payload.dig(:user, :id),
      user_email: @payload.dig(:user, :email),
      user_data: @payload[:user] || {},

      context: @payload[:context] || {},
      tags: @payload[:tags] || {},
      extra: @payload[:extra] || {},
      breadcrumbs: @payload[:breadcrumbs] || [],

      occurred_at: parse_timestamp(@payload[:timestamp]) || Time.current
    )
  end

  def normalize_backtrace(backtrace)
    return [] unless backtrace.is_a?(Array)

    backtrace.map do |frame|
      if frame.is_a?(String)
        # Parse Ruby backtrace string: "app/models/user.rb:42:in `save'"
        match = frame.match(/^(.+):(\d+):in `(.+)'$/)
        if match
          {
            "file" => match[1],
            "line" => match[2].to_i,
            "function" => match[3],
            "in_app" => in_app?(match[1])
          }
        else
          { "file" => frame, "line" => 0, "function" => "", "in_app" => false }
        end
      else
        frame.merge("in_app" => in_app?(frame["file"]))
      end
    end
  end

  def in_app?(file_path)
    return false if file_path.nil?
    return false if file_path.include?("/gems/")
    return false if file_path.include?("vendor/")
    return false if file_path.include?("/ruby/")

    # Match both relative and absolute paths containing app/ or lib/
    file_path.start_with?("app/", "lib/") ||
      file_path.include?("/app/") ||
      file_path.include?("/lib/")
  end

  def extract_file_path
    first_frame = @payload[:backtrace]&.first
    return nil unless first_frame

    if first_frame.is_a?(String)
      first_frame.match(/^(.+):\d+/)&.captures&.first
    else
      first_frame["file"]
    end
  end

  def extract_line_number
    first_frame = @payload[:backtrace]&.first
    return nil unless first_frame

    if first_frame.is_a?(String)
      first_frame.match(/:(\d+):/)&.captures&.first&.to_i
    else
      first_frame["line"]
    end
  end

  def extract_function_name
    first_frame = @payload[:backtrace]&.first
    return nil unless first_frame

    if first_frame.is_a?(String)
      first_frame.match(/in `(.+)'/)&.captures&.first
    else
      first_frame["function"]
    end
  end

  def sanitize_params(params)
    return {} unless params.is_a?(Hash)
    # Remove sensitive keys
    sensitive_keys = %w[password password_confirmation token api_key secret credit_card cvv]

    params.transform_keys(&:to_s).each_with_object({}) do |(key, value), result|
      if sensitive_keys.include?(key.to_s.downcase)
        result[key] = "[FILTERED]"
      elsif value.is_a?(Hash)
        result[key] = sanitize_params(value)
      else
        result[key] = value
      end
    end
  end

  def parse_timestamp(timestamp)
    case timestamp
    when Time, DateTime then timestamp
    when String then Time.parse(timestamp)
    when Numeric then Time.at(timestamp)
    else nil
    end
  rescue
    nil
  end

  def broadcast_new_error(error_group, event)
    ErrorsChannel.broadcast_to(@project, {
      type: "new_error",
      error_group: {
        id: error_group.id,
        error_class: error_group.error_class,
        message: error_group.short_message,
        event_count: error_group.event_count,
        last_seen_at: error_group.last_seen_at
      },
      event: {
        id: event.id,
        environment: event.environment,
        commit: event.commit
      }
    })
  rescue StandardError => e
    Rails.logger.warn("[ErrorProcessor] Broadcast failed: #{e.message}")
  end

  def maybe_notify(error_group, event)
    return unless error_group.notifications_enabled
    return if error_group.last_notified_at && error_group.last_notified_at > 5.minutes.ago

    SendNotificationJob.perform_later(error_group.id, event.id)
    error_group.update!(last_notified_at: Time.current)
  rescue StandardError => e
    Rails.logger.warn("[ErrorProcessor] Notification scheduling failed: #{e.message}")
  end
end
