class ErrorGroup < ApplicationRecord
  belongs_to :project, counter_cache: :error_count
  has_many :events, class_name: "ErrorEvent", dependent: :destroy

  STATUSES = %w[unresolved resolved ignored muted].freeze

  validates :fingerprint, presence: true, uniqueness: { scope: :project_id }
  validates :error_class, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :unresolved, -> { where(status: "unresolved") }
  scope :resolved, -> { where(status: "resolved") }
  scope :ignored, -> { where(status: "ignored") }
  scope :muted, -> { where(status: "muted") }
  scope :active, -> { where(status: %w[unresolved muted]) }
  scope :recent, -> { order(last_seen_at: :desc) }
  scope :frequent, -> { order(event_count: :desc) }

  def resolve!(user_id: nil)
    update!(
      status: "resolved",
      resolved_at: Time.current,
      resolved_by: user_id
    )
  end

  def unresolve!
    update!(
      status: "unresolved",
      resolved_at: nil,
      resolved_by: nil
    )
  end

  def ignore!
    update!(status: "ignored")
  end

  def mute!(duration: nil)
    update!(status: "muted")
    # TODO: Schedule unmute if duration provided
  end

  def record_occurrence!(event)
    update!(
      event_count: event_count + 1,
      last_seen_at: event.occurred_at,
      last_commit: event.commit,
      last_environment: event.environment
    )

    # Unresolve if it was resolved and happens again
    unresolve! if resolved?
  end

  def resolved?
    status == "resolved"
  end

  def short_message
    message&.lines&.first&.truncate(100)
  end

  def location
    return nil unless file_path
    "#{file_path}:#{line_number} in #{function_name}"
  end
end
