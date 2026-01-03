# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::ReflexStatsTest < ActiveSupport::TestCase
  setup do
    @project = create_project
    @tool = Mcp::Tools::ReflexStats.new(@project)
  end

  test "returns total errors count" do
    3.times { create_error_group(project: @project) }

    result = @tool.call({})

    assert_equal 3, result[:total_errors]
  end

  test "returns unresolved count" do
    create_error_group(project: @project, status: "unresolved")
    create_error_group(project: @project, status: "unresolved")
    create_error_group(project: @project, status: "resolved")

    result = @tool.call({})

    assert_equal 2, result[:unresolved]
  end

  test "returns resolved count" do
    create_error_group(project: @project, status: "unresolved")
    create_error_group(project: @project, status: "resolved")
    create_error_group(project: @project, status: "resolved")

    result = @tool.call({})

    assert_equal 2, result[:resolved]
  end

  test "returns ignored count" do
    create_error_group(project: @project, status: "unresolved")
    create_error_group(project: @project, status: "ignored")

    result = @tool.call({})

    assert_equal 1, result[:ignored]
  end

  test "returns events in period count" do
    error = create_error_group(project: @project)
    create_error_event(error_group: error, occurred_at: 1.hour.ago)
    create_error_event(error_group: error, occurred_at: 12.hours.ago)
    create_error_event(error_group: error, occurred_at: 2.days.ago)  # Outside default 24h

    result = @tool.call({})

    assert_equal 2, result[:events_in_period]
  end

  test "respects since parameter for hours" do
    error = create_error_group(project: @project)
    create_error_event(error_group: error, occurred_at: 30.minutes.ago)
    create_error_event(error_group: error, occurred_at: 3.hours.ago)  # Outside 1h

    result = @tool.call(since: "1h")

    assert_equal 1, result[:events_in_period]
  end

  test "respects since parameter for days" do
    error = create_error_group(project: @project)
    create_error_event(error_group: error, occurred_at: 1.day.ago)
    create_error_event(error_group: error, occurred_at: 5.days.ago)
    create_error_event(error_group: error, occurred_at: 10.days.ago)  # Outside 7d

    result = @tool.call(since: "7d")

    assert_equal 2, result[:events_in_period]
  end

  test "respects since parameter for weeks" do
    error = create_error_group(project: @project)
    create_error_event(error_group: error, occurred_at: 1.week.ago)
    create_error_event(error_group: error, occurred_at: 3.weeks.ago)  # Outside 2w

    result = @tool.call(since: "2w")

    assert_equal 1, result[:events_in_period]
  end

  test "returns top errors" do
    frequent_error = create_error_group(project: @project, event_count: 100, error_class: "FrequentError")
    rare_error = create_error_group(project: @project, event_count: 5, error_class: "RareError")

    result = @tool.call({})

    assert result[:top_errors].is_a?(Array)
    assert result[:top_errors].length > 0

    top_error = result[:top_errors].first
    assert_equal "FrequentError", top_error[:error_class]
    assert_equal 100, top_error[:count]
  end

  test "limits top errors to 5" do
    10.times { |i| create_error_group(project: @project, event_count: i + 1) }

    result = @tool.call({})

    assert_equal 5, result[:top_errors].length
  end

  test "only includes unresolved errors in top errors" do
    create_error_group(project: @project, status: "unresolved", event_count: 100)
    create_error_group(project: @project, status: "resolved", event_count: 200)

    result = @tool.call({})

    assert_equal 1, result[:top_errors].length
    assert_equal 100, result[:top_errors].first[:count]
  end

  test "returns events by environment" do
    error = create_error_group(project: @project)
    create_error_event(error_group: error, environment: "production", occurred_at: 1.hour.ago)
    create_error_event(error_group: error, environment: "production", occurred_at: 2.hours.ago)
    create_error_event(error_group: error, environment: "staging", occurred_at: 3.hours.ago)

    result = @tool.call({})

    assert result[:by_environment].present?
    assert_equal 2, result[:by_environment]["production"]
    assert_equal 1, result[:by_environment]["staging"]
  end

  test "returns empty stats when no data" do
    result = @tool.call({})

    assert_equal 0, result[:total_errors]
    assert_equal 0, result[:unresolved]
    assert_equal 0, result[:resolved]
    assert_equal 0, result[:ignored]
    assert_equal 0, result[:events_in_period]
    assert_equal [], result[:top_errors]
  end

  test "has correct DESCRIPTION" do
    assert Mcp::Tools::ReflexStats::DESCRIPTION.present?
    assert Mcp::Tools::ReflexStats::DESCRIPTION.downcase.include?("statistics")
  end

  test "has correct SCHEMA" do
    schema = Mcp::Tools::ReflexStats::SCHEMA

    assert_equal "object", schema[:type]
    assert schema[:properties][:since].present?
  end
end
