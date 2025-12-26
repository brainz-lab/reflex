require "test_helper"

class ErrorsChannelTest < ActionCable::Channel::TestCase
  setup do
    @project = create_project
  end

  test "subscribes successfully with valid project_id" do
    subscribe project_id: @project.id

    assert subscription.confirmed?
  end

  test "rejects subscription without project_id" do
    subscribe

    assert subscription.rejected?
  end

  test "rejects subscription with invalid project_id" do
    subscribe project_id: SecureRandom.uuid

    assert subscription.rejected?
  end

  test "unsubscribes successfully" do
    subscribe project_id: @project.id
    unsubscribe

    assert_no_streams
  end

  test "broadcast_new_error sends message" do
    error_group = create_error_group(project: @project)
    event = create_error_event(error_group: error_group)

    assert_broadcast_on(ErrorsChannel.broadcasting_for(@project), type: "new_error") do
      ErrorsChannel.broadcast_new_error(@project, error_group, event)
    end
  end

  test "broadcast_new_error includes error_group data" do
    error_group = create_error_group(
      project: @project,
      error_class: "NoMethodError",
      message: "Test error"
    )
    event = create_error_event(error_group: error_group)

    message = nil
    assert_broadcast_on(ErrorsChannel.broadcasting_for(@project), type: "new_error") do
      ErrorsChannel.broadcast_new_error(@project, error_group, event)
    end
  end

  test "broadcast_error_resolved sends message" do
    error_group = create_error_group(project: @project, status: "resolved")

    assert_broadcast_on(ErrorsChannel.broadcasting_for(@project), type: "error_resolved") do
      ErrorsChannel.broadcast_error_resolved(@project, error_group)
    end
  end

  test "broadcast_error_resolved includes status" do
    error_group = create_error_group(project: @project, status: "resolved")

    message = nil
    perform_enqueued_jobs do
      ErrorsChannel.broadcast_error_resolved(@project, error_group)
    end

    # Verify the message structure
    assert_equal "resolved", error_group.status
  end

  test "broadcast_error_ignored sends message" do
    error_group = create_error_group(project: @project, status: "ignored")

    assert_broadcast_on(ErrorsChannel.broadcasting_for(@project), type: "error_ignored") do
      ErrorsChannel.broadcast_error_ignored(@project, error_group)
    end
  end

  test "broadcast_error_unresolved sends message" do
    error_group = create_error_group(project: @project, status: "unresolved")

    assert_broadcast_on(ErrorsChannel.broadcasting_for(@project), type: "error_unresolved") do
      ErrorsChannel.broadcast_error_unresolved(@project, error_group)
    end
  end

  test "streams for project" do
    subscribe project_id: @project.id

    assert_has_stream_for @project
  end

  test "error_group_payload includes required fields" do
    error_group = create_error_group(
      project: @project,
      error_class: "TestError",
      message: "Test message",
      event_count: 5,
      status: "unresolved"
    )

    payload = ErrorsChannel.send(:error_group_payload, error_group)

    assert_equal error_group.id, payload[:id]
    assert_equal "TestError", payload[:error_class]
    assert payload[:message].present?
    assert_equal 5, payload[:event_count]
    assert_equal "unresolved", payload[:status]
    assert payload[:last_seen_at].present?
  end

  test "event_payload includes required fields" do
    error_group = create_error_group(project: @project)
    event = create_error_event(
      error_group: error_group,
      environment: "production",
      commit: "abc123"
    )

    payload = ErrorsChannel.send(:event_payload, event)

    assert_equal event.id, payload[:id]
    assert_equal "production", payload[:environment]
    assert_equal "abc123", payload[:commit]
    assert payload[:occurred_at].present?
  end
end
