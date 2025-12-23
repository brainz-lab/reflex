class ErrorsChannel < ApplicationCable::Channel
  def subscribed
    project = Project.find_by(id: params[:project_id])
    if project
      stream_for project
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  # Broadcast helpers for use throughout the application
  class << self
    def broadcast_new_error(project, error_group, event)
      broadcast_to(project, {
        type: "new_error",
        error_group: error_group_payload(error_group),
        event: event_payload(event)
      })
    end

    def broadcast_error_resolved(project, error_group)
      broadcast_to(project, {
        type: "error_resolved",
        error_group_id: error_group.id,
        status: error_group.status
      })
    end

    def broadcast_error_ignored(project, error_group)
      broadcast_to(project, {
        type: "error_ignored",
        error_group_id: error_group.id,
        status: error_group.status
      })
    end

    def broadcast_error_unresolved(project, error_group)
      broadcast_to(project, {
        type: "error_unresolved",
        error_group_id: error_group.id,
        status: error_group.status
      })
    end

    private

    def error_group_payload(error_group)
      {
        id: error_group.id,
        error_class: error_group.error_class,
        message: error_group.respond_to?(:short_message) ? error_group.short_message : error_group.message&.truncate(100),
        event_count: error_group.event_count,
        status: error_group.status,
        last_seen_at: error_group.last_seen_at
      }
    end

    def event_payload(event)
      {
        id: event.id,
        environment: event.environment,
        commit: event.commit,
        occurred_at: event.occurred_at
      }
    end
  end
end
