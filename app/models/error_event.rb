class ErrorEvent < ApplicationRecord
  belongs_to :error_group, counter_cache: :event_count
  belongs_to :project, counter_cache: :event_count

  validates :error_class, presence: true
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }

  def parsed_backtrace
    backtrace.map do |frame|
      {
        file: frame['file'],
        line: frame['line'],
        function: frame['function'],
        context: frame['context'],  # Lines of code around the error
        in_app: frame['in_app']     # Is this our code or a gem?
      }
    end
  end

  def app_backtrace
    parsed_backtrace.select { |f| f[:in_app] }
  end

  def first_app_frame
    app_backtrace.first
  end
end
