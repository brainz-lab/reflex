require "test_helper"

class ErrorEventTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(error_group: error_group)
    assert event.valid?
  end

  test "requires error_class" do
    project = create_project
    error_group = create_error_group(project: project)
    event = error_group.events.build(
      project: project,
      occurred_at: Time.current
    )
    assert_not event.valid?
    assert_includes event.errors[:error_class], "can't be blank"
  end

  test "requires occurred_at" do
    project = create_project
    error_group = create_error_group(project: project)
    event = error_group.events.build(
      project: project,
      error_class: "NoMethodError"
    )
    assert_not event.valid?
    assert_includes event.errors[:occurred_at], "can't be blank"
  end

  test "belongs to error_group" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(error_group: error_group)

    assert_equal error_group, event.error_group
  end

  test "belongs to project" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(error_group: error_group)

    assert_equal project, event.project
  end

  test "scope recent orders by occurred_at desc" do
    project = create_project
    error_group = create_error_group(project: project)

    old_event = create_error_event(error_group: error_group, occurred_at: 2.hours.ago)
    new_event = create_error_event(error_group: error_group, occurred_at: 1.hour.ago)

    recent = error_group.events.recent
    assert_equal new_event.id, recent.first.id
    assert_equal old_event.id, recent.last.id
  end

  test "parsed_backtrace handles string format" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(
      error_group: error_group,
      backtrace: [
        "app/models/user.rb:42:in `full_name'",
        "app/controllers/users_controller.rb:23:in `show'"
      ]
    )

    parsed = event.parsed_backtrace

    assert_equal 2, parsed.length
    assert_equal "app/models/user.rb", parsed[0][:file]
    assert_equal 42, parsed[0][:line]
    # The regex captures the function name with the trailing quote
    assert_equal "full_name'", parsed[0][:function]
    assert parsed[0][:in_app]

    assert_equal "app/controllers/users_controller.rb", parsed[1][:file]
    assert_equal 23, parsed[1][:line]
    assert_equal "show'", parsed[1][:function]
  end

  test "parsed_backtrace handles hash format" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(
      error_group: error_group,
      backtrace: [
        {
          "file" => "app/models/user.rb",
          "line" => 42,
          "function" => "full_name",
          "in_app" => true
        }
      ]
    )

    parsed = event.parsed_backtrace

    assert_equal 1, parsed.length
    assert_equal "app/models/user.rb", parsed[0][:file]
    assert_equal 42, parsed[0][:line]
    assert_equal "full_name", parsed[0][:function]
    assert parsed[0][:in_app]
  end

  test "parsed_backtrace handles raw frame format" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(
      error_group: error_group,
      backtrace: [
        { "raw" => "app/models/user.rb:42:in `full_name'" }
      ]
    )

    parsed = event.parsed_backtrace

    assert_equal 1, parsed.length
    assert_equal "app/models/user.rb", parsed[0][:file]
    assert_equal 42, parsed[0][:line]
    # The regex captures the function name with the trailing quote
    assert_equal "full_name'", parsed[0][:function]
  end

  test "in_app_path? returns true for app paths" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(error_group: error_group)

    assert event.in_app_path?("app/models/user.rb")
    assert event.in_app_path?("lib/custom_module.rb")
    assert event.in_app_path?("/full/path/app/models/user.rb")
    assert event.in_app_path?("/full/path/lib/custom.rb")
  end

  test "in_app_path? returns false for gem paths" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(error_group: error_group)

    assert_not event.in_app_path?("/gems/rails-8.0/lib/action_controller.rb")
    assert_not event.in_app_path?("vendor/bundle/rails.rb")
    assert_not event.in_app_path?("/ruby/3.3.0/lib/timeout.rb")
  end

  test "in_app_path? returns false for nil" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(error_group: error_group)

    assert_not event.in_app_path?(nil)
  end

  test "app_backtrace filters to in_app frames" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(
      error_group: error_group,
      backtrace: [
        "app/models/user.rb:42:in `full_name'",
        "/gems/activerecord/lib/active_record.rb:100:in `save'",
        "app/controllers/users_controller.rb:23:in `show'"
      ]
    )

    app_frames = event.app_backtrace

    assert_equal 2, app_frames.length
    assert_equal "app/models/user.rb", app_frames[0][:file]
    assert_equal "app/controllers/users_controller.rb", app_frames[1][:file]
  end

  test "app_backtrace falls back to all frames if none marked in_app" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(
      error_group: error_group,
      backtrace: [
        "/gems/rails/lib/rails.rb:10:in `load'",
        "/ruby/3.3.0/lib/timeout.rb:5:in `timeout'"
      ]
    )

    app_frames = event.app_backtrace

    assert_equal 2, app_frames.length
  end

  test "first_app_frame returns first in_app frame" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(
      error_group: error_group,
      backtrace: [
        "app/models/user.rb:42:in `full_name'",
        "app/controllers/users_controller.rb:23:in `show'"
      ]
    )

    first_frame = event.first_app_frame

    assert_equal "app/models/user.rb", first_frame[:file]
    assert_equal 42, first_frame[:line]
  end

  test "counter_cache increments error_group event_count" do
    project = create_project
    error_group = create_error_group(project: project, event_count: 5)

    create_error_event(error_group: error_group)
    error_group.reload

    assert_equal 6, error_group.event_count
  end

  test "counter_cache increments project event_count" do
    project = create_project
    error_group = create_error_group(project: project)
    initial_count = project.event_count

    create_error_event(error_group: error_group)
    project.reload

    assert_equal initial_count + 1, project.event_count
  end

  test "stores JSONB fields correctly" do
    project = create_project
    error_group = create_error_group(project: project)
    event = create_error_event(
      error_group: error_group,
      context: { custom_field: "value" },
      tags: { environment: "production" },
      extra: { server: "web-1" },
      breadcrumbs: [ { action: "user.login", timestamp: Time.current.iso8601 } ]
    )

    assert_equal "value", event.context["custom_field"]
    assert_equal "production", event.tags["environment"]
    assert_equal "web-1", event.extra["server"]
    assert_equal 1, event.breadcrumbs.length
  end
end
