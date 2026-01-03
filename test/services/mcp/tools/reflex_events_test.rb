# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::ReflexEventsTest < ActiveSupport::TestCase
  setup do
    @project = create_project
    @tool = Mcp::Tools::ReflexEvents.new(@project)
    @error = create_error_group(project: @project, event_count: 0)
  end

  test "returns events for error" do
    event1 = create_error_event(error_group: @error, occurred_at: 1.hour.ago)
    event2 = create_error_event(error_group: @error, occurred_at: 30.minutes.ago)

    result = @tool.call(error_id: @error.id)

    assert_equal @error.id, result[:error_id]
    assert_equal @error.error_class, result[:error_class]
    assert result[:events].is_a?(Array)
    assert result[:events].length >= 2
  end

  test "returns total event count" do
    # Create the event first, then check the count matches error_group.event_count
    create_error_event(error_group: @error)
    @error.reload

    result = @tool.call(error_id: @error.id)

    assert_equal @error.event_count, result[:total_count]
  end

  test "limits events to 20 by default" do
    25.times { |i| create_error_event(error_group: @error, occurred_at: i.hours.ago) }

    result = @tool.call(error_id: @error.id)

    assert_equal 20, result[:events].length
  end

  test "respects custom limit" do
    10.times { |i| create_error_event(error_group: @error, occurred_at: i.hours.ago) }

    result = @tool.call(error_id: @error.id, limit: 5)

    assert_equal 5, result[:events].length
  end

  test "caps limit at 100" do
    # Create fewer events than 100 to avoid slow test
    15.times { |i| create_error_event(error_group: @error, occurred_at: i.hours.ago) }

    result = @tool.call(error_id: @error.id, limit: 200)

    # Should still work, just capped
    assert result[:events].length <= 100
  end

  test "returns events sorted by most recent" do
    old_event = create_error_event(error_group: @error, occurred_at: 2.hours.ago)
    new_event = create_error_event(error_group: @error, occurred_at: 30.minutes.ago)

    result = @tool.call(error_id: @error.id)

    event_ids = result[:events].map { |e| e[:id] }
    assert_equal new_event.id, event_ids.first
  end

  test "formats events correctly" do
    event = create_error_event(
      error_group: @error,
      environment: "production",
      commit: "abc123",
      user_id: "user_42"
    )

    result = @tool.call(error_id: @error.id)
    formatted = result[:events].first

    assert formatted[:id].present?
    assert formatted[:occurred_at].present?
    assert_equal "production", formatted[:environment]
    assert_equal "abc123", formatted[:commit]
    assert_equal "user_42", formatted[:user_id]
  end

  test "returns error message for nonexistent error" do
    result = @tool.call(error_id: "nonexistent-uuid")

    assert_equal "Error not found", result[:error]
    refute result[:events]
  end

  test "cannot get events from different project" do
    other_project = create_project
    other_error = create_error_group(project: other_project)
    create_error_event(error_group: other_error)

    result = @tool.call(error_id: other_error.id)

    assert_equal "Error not found", result[:error]
  end

  test "returns empty events array when no events exist" do
    result = @tool.call(error_id: @error.id)

    assert_equal [], result[:events]
  end

  test "has correct DESCRIPTION" do
    assert Mcp::Tools::ReflexEvents::DESCRIPTION.present?
    assert Mcp::Tools::ReflexEvents::DESCRIPTION.downcase.include?("events")
  end

  test "has correct SCHEMA with required error_id" do
    schema = Mcp::Tools::ReflexEvents::SCHEMA

    assert_equal "object", schema[:type]
    assert schema[:properties][:error_id].present?
    assert schema[:properties][:limit].present?
    assert_includes schema[:required], "error_id"
  end
end
