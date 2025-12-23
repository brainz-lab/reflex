class ErrorEvent < ApplicationRecord
  include Timescaledb::Rails::Model
  include HypertableFindable

  belongs_to :error_group, counter_cache: :event_count
  belongs_to :project, counter_cache: :event_count

  validates :error_class, presence: true
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }

  def parsed_backtrace
    backtrace.map do |frame|
      if frame.is_a?(String)
        # Parse string format: "app/models/user.rb:42:in `full_name'"
        match = frame.match(/^(.+):(\d+):in [`'](.+)'?$/)
        if match
          {
            file: match[1],
            line: match[2].to_i,
            function: match[3],
            in_app: in_app_path?(match[1])
          }
        else
          { file: frame, line: nil, function: nil, in_app: false }
        end
      elsif frame['raw']
        # Handle raw frames from SDK that couldn't be parsed
        raw = frame['raw']
        match = raw.match(/^(.+):(\d+):in [`'](.+)'?$/)
        if match
          {
            file: match[1],
            line: match[2].to_i,
            function: match[3],
            in_app: in_app_path?(match[1])
          }
        else
          { file: raw, line: nil, function: nil, in_app: false }
        end
      else
        {
          file: frame['file'],
          line: frame['line'],
          function: frame['function'],
          context: frame['context'],
          in_app: frame['in_app']
        }
      end
    end
  end

  def in_app_path?(path)
    return false if path.nil?
    return false if path.include?('/gems/')
    return false if path.include?('vendor/')
    return false if path.include?('/ruby/')

    path.start_with?('app/', 'lib/') ||
      path.include?('/app/') ||
      path.include?('/lib/')
  end

  def app_backtrace
    result = parsed_backtrace.select { |f| f[:in_app] }
    result.any? ? result : parsed_backtrace  # Fall back to all frames if none marked in_app
  end

  def first_app_frame
    app_backtrace.first
  end
end
