# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::ReflexShowTest < ActiveSupport::TestCase
  setup do
    @project = create_project
    @tool = Mcp::Tools::ReflexShow.new(@project)
  end

  test "returns error details" do
    error = create_error_group(
      project: @project,
      error_class: "NoMethodError",
      message: "undefined method 'foo' for nil:NilClass",
      file_path: "app/models/user.rb",
      line_number: 42,
      function_name: "full_name"
    )

    result = @tool.call(error_id: error.id)

    assert result[:error].present?
    assert_equal error.id, result[:error][:id]
    assert_equal "NoMethodError", result[:error][:error_class]
    assert_equal "undefined method 'foo' for nil:NilClass", result[:error][:message]
    assert_equal "app/models/user.rb", result[:error][:file_path]
    assert_equal 42, result[:error][:line_number]
    assert_equal "full_name", result[:error][:function_name]
  end

  test "includes error status" do
    error = create_error_group(project: @project, status: "resolved")

    result = @tool.call(error_id: error.id)

    assert_equal "resolved", result[:error][:status]
  end

  test "includes event count" do
    error = create_error_group(project: @project, event_count: 42)

    result = @tool.call(error_id: error.id)

    assert_equal 42, result[:error][:event_count]
  end

  test "includes first and last seen timestamps" do
    first_seen = 2.days.ago
    last_seen = 1.hour.ago
    error = create_error_group(project: @project, first_seen_at: first_seen, last_seen_at: last_seen)

    result = @tool.call(error_id: error.id)

    assert result[:error][:first_seen].present?
    assert result[:error][:last_seen].present?
  end

  test "includes location" do
    error = create_error_group(
      project: @project,
      file_path: "app/models/user.rb",
      line_number: 42,
      function_name: "full_name"
    )

    result = @tool.call(error_id: error.id)

    assert result[:error][:location].include?("app/models/user.rb")
  end

  test "returns recent events" do
    error = create_error_group(project: @project)
    event1 = create_error_event(error_group: error, occurred_at: 1.hour.ago)
    event2 = create_error_event(error_group: error, occurred_at: 30.minutes.ago)

    result = @tool.call(error_id: error.id)

    assert result[:recent_events].is_a?(Array)
    assert result[:recent_events].length >= 2
  end

  test "limits recent events to 5" do
    error = create_error_group(project: @project)
    10.times { |i| create_error_event(error_group: error, occurred_at: i.hours.ago) }

    result = @tool.call(error_id: error.id)

    assert_equal 5, result[:recent_events].length
  end

  test "formats events correctly" do
    error = create_error_group(project: @project)
    event = create_error_event(
      error_group: error,
      environment: "production",
      commit: "abc123",
      user_id: "user_1"
    )

    result = @tool.call(error_id: error.id)
    formatted = result[:recent_events].first

    assert formatted[:id].present?
    assert formatted[:occurred_at].present?
    assert_equal "production", formatted[:environment]
    assert_equal "abc123", formatted[:commit]
    assert_equal "user_1", formatted[:user_id]
  end

  test "returns error message for nonexistent error" do
    result = @tool.call(error_id: "nonexistent-uuid")

    assert_equal "Error not found", result[:error]
    refute result[:recent_events]
  end

  test "returns error for error from different project" do
    other_project = create_project
    other_error = create_error_group(project: other_project)

    result = @tool.call(error_id: other_error.id)

    assert_equal "Error not found", result[:error]
  end

  test "has correct DESCRIPTION" do
    assert Mcp::Tools::ReflexShow::DESCRIPTION.present?
    assert Mcp::Tools::ReflexShow::DESCRIPTION.include?("details")
  end

  test "has correct SCHEMA with required error_id" do
    schema = Mcp::Tools::ReflexShow::SCHEMA

    assert_equal "object", schema[:type]
    assert schema[:properties][:error_id].present?
    assert_includes schema[:required], "error_id"
  end
end
