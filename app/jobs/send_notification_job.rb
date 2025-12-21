class SendNotificationJob < ApplicationJob
  queue_as :default

  def perform(error_group_id, event_id)
    error_group = ErrorGroup.find_by(id: error_group_id)
    event = ErrorEvent.find_by(id: event_id)

    return unless error_group && event

    # TODO: Implement notification sending
    # This could send webhooks, emails, Slack messages, etc.
    Rails.logger.info("[Notification] New error: #{error_group.error_class} - #{error_group.short_message}")
  end
end
