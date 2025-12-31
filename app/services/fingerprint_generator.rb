require "digest"

class FingerprintGenerator
  def self.generate(payload)
    # Create a unique fingerprint based on error class and location
    components = [
      payload[:error_class] || payload.dig(:exception, :class),
      extract_file(payload),
      extract_function(payload),
      # Optionally include normalized message
      normalize_message(payload[:message] || payload.dig(:exception, :message))
    ].compact

    Digest::SHA256.hexdigest(components.join("|"))[0..15]
  end

  def self.extract_file(payload)
    backtrace = payload[:backtrace] || payload.dig(:exception, :backtrace) || []
    first_frame = backtrace.first

    if first_frame.is_a?(String)
      first_frame.match(/^(.+):\d+/)&.captures&.first
    elsif first_frame.is_a?(Hash)
      first_frame["file"]
    end
  end

  def self.extract_function(payload)
    backtrace = payload[:backtrace] || payload.dig(:exception, :backtrace) || []
    first_frame = backtrace.first

    if first_frame.is_a?(String)
      first_frame.match(/in `(.+)'/)&.captures&.first
    elsif first_frame.is_a?(Hash)
      first_frame["function"]
    end
  end

  def self.normalize_message(message)
    return nil unless message

    # Remove dynamic parts from message
    message
      .gsub(/\b[0-9a-f]{8,}\b/i, "ID")     # Hex IDs
      .gsub(/\b\d+\b/, "N")                  # Numbers
      .gsub(/"[^"]*"/, '"..."')              # Quoted strings
      .gsub(/'[^']*'/, "'...'")              # Single quoted strings
      .truncate(200)
  end
end
