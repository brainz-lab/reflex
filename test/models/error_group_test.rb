require "test_helper"

class ErrorGroupTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    project = create_project
    error_group = create_error_group(project: project)
    assert error_group.valid?
  end

  test "requires fingerprint" do
    project = create_project
    error_group = project.error_groups.build(
      error_class: "NoMethodError",
      status: "unresolved"
    )
    assert_not error_group.valid?
    assert_includes error_group.errors[:fingerprint], "can't be blank"
  end

  test "requires error_class" do
    project = create_project
    error_group = project.error_groups.build(
      fingerprint: "abc123",
      status: "unresolved"
    )
    assert_not error_group.valid?
    assert_includes error_group.errors[:error_class], "can't be blank"
  end

  test "fingerprint must be unique within project scope" do
    project = create_project
    create_error_group(project: project, fingerprint: "unique123")

    duplicate = project.error_groups.build(
      fingerprint: "unique123",
      error_class: "RuntimeError",
      status: "unresolved"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:fingerprint], "has already been taken"
  end

  test "same fingerprint allowed in different projects" do
    project1 = create_project(platform_project_id: "prj_1")
    project2 = create_project(platform_project_id: "prj_2")

    create_error_group(project: project1, fingerprint: "shared123")

    error_group2 = project2.error_groups.build(
      fingerprint: "shared123",
      error_class: "NoMethodError",
      status: "unresolved"
    )
    assert error_group2.valid?
  end

  test "validates status inclusion" do
    project = create_project
    error_group = project.error_groups.build(
      fingerprint: "abc123",
      error_class: "NoMethodError",
      status: "invalid_status"
    )
    assert_not error_group.valid?
    assert_includes error_group.errors[:status], "is not included in the list"
  end

  test "accepts valid statuses" do
    project = create_project
    ErrorGroup::STATUSES.each do |status|
      error_group = create_error_group(project: project, status: status)
      assert error_group.valid?, "#{status} should be a valid status"
    end
  end

  test "belongs to project" do
    project = create_project
    error_group = create_error_group(project: project)
    assert_equal project, error_group.project
  end

  test "has many events" do
    project = create_project
    error_group = create_error_group(project: project)
    assert_respond_to error_group, :events
  end

  test "scopes: unresolved" do
    project = create_project
    unresolved = create_error_group(project: project, status: "unresolved")
    resolved = create_error_group(project: project, status: "resolved")

    assert_includes ErrorGroup.unresolved, unresolved
    assert_not_includes ErrorGroup.unresolved, resolved
  end

  test "scopes: resolved" do
    project = create_project
    resolved = create_error_group(project: project, status: "resolved")
    unresolved = create_error_group(project: project, status: "unresolved")

    assert_includes ErrorGroup.resolved, resolved
    assert_not_includes ErrorGroup.resolved, unresolved
  end

  test "scopes: ignored" do
    project = create_project
    ignored = create_error_group(project: project, status: "ignored")
    unresolved = create_error_group(project: project, status: "unresolved")

    assert_includes ErrorGroup.ignored, ignored
    assert_not_includes ErrorGroup.ignored, unresolved
  end

  test "scopes: muted" do
    project = create_project
    muted = create_error_group(project: project, status: "muted")
    unresolved = create_error_group(project: project, status: "unresolved")

    assert_includes ErrorGroup.muted, muted
    assert_not_includes ErrorGroup.muted, unresolved
  end

  test "scopes: active" do
    project = create_project
    unresolved = create_error_group(project: project, status: "unresolved")
    muted = create_error_group(project: project, status: "muted")
    resolved = create_error_group(project: project, status: "resolved")

    active_groups = ErrorGroup.active
    assert_includes active_groups, unresolved
    assert_includes active_groups, muted
    assert_not_includes active_groups, resolved
  end

  test "scopes: recent orders by last_seen_at desc" do
    project = create_project
    old = create_error_group(project: project, last_seen_at: 2.hours.ago)
    new = create_error_group(project: project, last_seen_at: 1.hour.ago)

    recent = project.error_groups.recent
    assert_equal new, recent.first
    assert_equal old, recent.last
  end

  test "scopes: frequent orders by event_count desc" do
    project = create_project
    low = create_error_group(project: project, event_count: 5)
    high = create_error_group(project: project, event_count: 100)

    frequent = project.error_groups.frequent
    assert_equal high, frequent.first
    assert_equal low, frequent.last
  end

  test "resolve! marks as resolved" do
    project = create_project
    error_group = create_error_group(project: project, status: "unresolved")

    error_group.resolve!(user_id: "user_123")

    assert_equal "resolved", error_group.status
    assert_not_nil error_group.resolved_at
    assert_equal "user_123", error_group.resolved_by
  end

  test "unresolve! marks as unresolved" do
    project = create_project
    error_group = create_error_group(
      project: project,
      status: "resolved",
      resolved_at: 1.hour.ago,
      resolved_by: "user_123"
    )

    error_group.unresolve!

    assert_equal "unresolved", error_group.status
    assert_nil error_group.resolved_at
    assert_nil error_group.resolved_by
  end

  test "ignore! marks as ignored" do
    project = create_project
    error_group = create_error_group(project: project, status: "unresolved")

    error_group.ignore!

    assert_equal "ignored", error_group.status
  end

  test "mute! marks as muted" do
    project = create_project
    error_group = create_error_group(project: project, status: "unresolved")

    error_group.mute!

    assert_equal "muted", error_group.status
  end

  test "record_occurrence! updates stats" do
    project = create_project
    error_group = create_error_group(
      project: project,
      event_count: 5,
      last_seen_at: 1.hour.ago
    )

    event = create_error_event(
      error_group: error_group,
      occurred_at: Time.current,
      commit: "xyz789",
      environment: "staging"
    )

    # Note: counter_cache already incremented to 6 when event was created
    # record_occurrence! will increment it to 7
    error_group.reload  # Get the counter_cache updated value
    initial_count = error_group.event_count

    error_group.record_occurrence!(event)

    assert_equal initial_count + 1, error_group.event_count
    assert_in_delta Time.current.to_i, error_group.last_seen_at.to_i, 1
    assert_equal "xyz789", error_group.last_commit
    assert_equal "staging", error_group.last_environment
  end

  test "record_occurrence! unresolves if resolved" do
    project = create_project
    error_group = create_error_group(
      project: project,
      status: "resolved",
      resolved_at: 1.hour.ago
    )

    event = create_error_event(error_group: error_group)
    error_group.record_occurrence!(event)

    assert_equal "unresolved", error_group.status
    assert_nil error_group.resolved_at
  end

  test "resolved? returns true when resolved" do
    project = create_project
    error_group = create_error_group(project: project, status: "resolved")
    assert error_group.resolved?
  end

  test "resolved? returns false when not resolved" do
    project = create_project
    error_group = create_error_group(project: project, status: "unresolved")
    assert_not error_group.resolved?
  end

  test "short_message truncates to 100 chars" do
    project = create_project
    long_message = "a" * 150
    error_group = create_error_group(project: project, message: long_message)

    assert_equal 100, error_group.short_message.length
  end

  test "short_message returns first line for multiline messages" do
    project = create_project
    multiline = "First line\nSecond line\nThird line"
    error_group = create_error_group(project: project, message: multiline)

    assert error_group.short_message.start_with?("First line")
  end

  test "location returns formatted location string" do
    project = create_project
    error_group = create_error_group(
      project: project,
      file_path: "app/models/user.rb",
      line_number: 42,
      function_name: "full_name"
    )

    assert_equal "app/models/user.rb:42 in full_name", error_group.location
  end

  test "location returns nil when file_path is nil" do
    project = create_project
    error_group = create_error_group(project: project, file_path: nil)

    assert_nil error_group.location
  end

  test "counter_cache increments project error_count" do
    project = create_project
    initial_count = project.error_count

    create_error_group(project: project)
    project.reload

    assert_equal initial_count + 1, project.error_count
  end
end
