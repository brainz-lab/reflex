require "test_helper"

class SendNotificationJobTest < ActiveSupport::TestCase
  test "performs job successfully" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(error_group: error_group)

    assert_nothing_raised do
      SendNotificationJob.perform_now(error_group.id, event.id)
    end
  end

  test "handles missing error_group gracefully" do
    event = create_error_event(error_group: create_error_group(project: create_project))

    assert_nothing_raised do
      SendNotificationJob.perform_now(SecureRandom.uuid, event.id)
    end
  end

  test "handles missing event gracefully" do
    error_group = create_error_group(project: create_project)

    assert_nothing_raised do
      SendNotificationJob.perform_now(error_group.id, SecureRandom.uuid)
    end
  end

  test "handles missing both gracefully" do
    assert_nothing_raised do
      SendNotificationJob.perform_now(SecureRandom.uuid, SecureRandom.uuid)
    end
  end

  test "logs notification message" do
    project = create_project
    error_group = create_error_group(project: project, error_class: "TestError", message: "Test message")
    event = create_error_event(error_group: error_group)

    # Capture log output
    log_output = StringIO.new
    old_logger = Rails.logger
    Rails.logger = Logger.new(log_output)

    SendNotificationJob.perform_now(error_group.id, event.id)

    Rails.logger = old_logger

    log_content = log_output.string
    assert_includes log_content, "[Notification]"
    assert_includes log_content, "TestError"
  end

  test "can be enqueued" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(error_group: error_group)

    assert_enqueued_with(job: SendNotificationJob) do
      SendNotificationJob.perform_later(error_group.id, event.id)
    end
  end
end
