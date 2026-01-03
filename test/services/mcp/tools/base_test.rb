# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::BaseTest < ActiveSupport::TestCase
  setup do
    @project = create_project
  end

  # Create a concrete subclass for testing the base class
  class TestTool < Mcp::Tools::Base
    def call(args)
      { result: "ok", args: args }
    end
  end

  test "initializes with project" do
    tool = TestTool.new(@project)

    assert_equal @project, tool.instance_variable_get(:@project)
  end

  test "call raises NotImplementedError in base class" do
    tool = Mcp::Tools::Base.new(@project)

    assert_raises(NotImplementedError) do
      tool.call({})
    end
  end

  test "format_error returns correct structure" do
    error = create_error_group(
      project: @project,
      error_class: "NoMethodError",
      message: "undefined method 'foo' for nil:NilClass\nMore details here",
      file_path: "app/models/user.rb",
      line_number: 42,
      function_name: "full_name",
      status: "unresolved",
      event_count: 10,
      last_commit: "abc123"
    )

    tool = TestTool.new(@project)
    formatted = tool.send(:format_error, error)

    assert_equal error.id, formatted[:id]
    assert_equal "NoMethodError", formatted[:error_class]
    assert formatted[:message].present?
    assert_equal "app/models/user.rb:42 in full_name", formatted[:location]
    assert_equal "unresolved", formatted[:status]
    assert_equal 10, formatted[:event_count]
    assert formatted[:first_seen].present?
    assert formatted[:last_seen].present?
    assert_equal "abc123", formatted[:last_commit]
  end

  test "format_event returns correct structure" do
    error = create_error_group(project: @project)
    event = create_error_event(
      error_group: error,
      environment: "production",
      commit: "abc123",
      user_id: "user_42",
      request_path: "/users/1"
    )

    tool = TestTool.new(@project)
    formatted = tool.send(:format_event, event)

    assert_equal event.id, formatted[:id]
    assert formatted[:occurred_at].present?
    assert_equal "production", formatted[:environment]
    assert_equal "abc123", formatted[:commit]
    assert_equal "user_42", formatted[:user_id]
  end

  test "parse_since handles hours" do
    tool = TestTool.new(@project)

    result = tool.send(:parse_since, "1h")
    assert_in_delta 1.hour.ago.to_i, result.to_i, 1

    result = tool.send(:parse_since, "6h")
    assert_in_delta 6.hours.ago.to_i, result.to_i, 1

    result = tool.send(:parse_since, "24h")
    assert_in_delta 24.hours.ago.to_i, result.to_i, 1
  end

  test "parse_since handles days" do
    tool = TestTool.new(@project)

    result = tool.send(:parse_since, "1d")
    assert_in_delta 1.day.ago.to_i, result.to_i, 1

    result = tool.send(:parse_since, "7d")
    assert_in_delta 7.days.ago.to_i, result.to_i, 1

    result = tool.send(:parse_since, "30d")
    assert_in_delta 30.days.ago.to_i, result.to_i, 1
  end

  test "parse_since handles weeks" do
    tool = TestTool.new(@project)

    result = tool.send(:parse_since, "1w")
    assert_in_delta 1.week.ago.to_i, result.to_i, 1

    result = tool.send(:parse_since, "2w")
    assert_in_delta 2.weeks.ago.to_i, result.to_i, 1
  end

  test "parse_since defaults to 24 hours for invalid input" do
    tool = TestTool.new(@project)

    result = tool.send(:parse_since, "invalid")
    assert_in_delta 24.hours.ago.to_i, result.to_i, 1

    result = tool.send(:parse_since, nil)
    assert_in_delta 24.hours.ago.to_i, result.to_i, 1

    result = tool.send(:parse_since, "")
    assert_in_delta 24.hours.ago.to_i, result.to_i, 1
  end
end
