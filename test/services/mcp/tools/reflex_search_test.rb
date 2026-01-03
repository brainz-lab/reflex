# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::ReflexSearchTest < ActiveSupport::TestCase
  setup do
    @project = create_project
    @tool = Mcp::Tools::ReflexSearch.new(@project)
  end

  test "returns all errors when no filters specified" do
    create_error_group(project: @project)
    create_error_group(project: @project)

    result = @tool.call({})

    assert_equal 2, result[:count]
    assert_equal 2, result[:errors].length
  end

  test "searches by query in error class" do
    matching = create_error_group(project: @project, error_class: "NoMethodError")
    non_matching = create_error_group(project: @project, error_class: "ArgumentError")

    result = @tool.call(query: "NoMethod")

    error_ids = result[:errors].map { |e| e[:id] }
    assert_includes error_ids, matching.id
    refute_includes error_ids, non_matching.id
  end

  test "searches by query in message" do
    matching = create_error_group(project: @project, message: "undefined method 'foo'")
    non_matching = create_error_group(project: @project, message: "invalid argument")

    result = @tool.call(query: "undefined")

    error_ids = result[:errors].map { |e| e[:id] }
    assert_includes error_ids, matching.id
    refute_includes error_ids, non_matching.id
  end

  test "query search is case insensitive" do
    matching = create_error_group(project: @project, error_class: "NoMethodError")

    result = @tool.call(query: "nomethoderror")

    assert_equal 1, result[:count]
    assert_equal matching.id, result[:errors].first[:id]
  end

  test "filters by exact error_class" do
    matching = create_error_group(project: @project, error_class: "NoMethodError")
    non_matching = create_error_group(project: @project, error_class: "ArgumentError")

    result = @tool.call(error_class: "NoMethodError")

    error_ids = result[:errors].map { |e| e[:id] }
    assert_includes error_ids, matching.id
    refute_includes error_ids, non_matching.id
  end

  test "filters by since time period" do
    recent = create_error_group(project: @project, last_seen_at: 1.hour.ago)
    old = create_error_group(project: @project, last_seen_at: 2.days.ago)

    result = @tool.call(since: "24h")

    error_ids = result[:errors].map { |e| e[:id] }
    assert_includes error_ids, recent.id
    refute_includes error_ids, old.id
  end

  test "filters by user_id through events" do
    error1 = create_error_group(project: @project)
    error2 = create_error_group(project: @project)

    create_error_event(error_group: error1, user_id: "user_123")
    create_error_event(error_group: error2, user_id: "user_456")

    result = @tool.call(user_id: "user_123")

    error_ids = result[:errors].map { |e| e[:id] }
    assert_includes error_ids, error1.id
    refute_includes error_ids, error2.id
  end

  test "filters by commit through events" do
    error1 = create_error_group(project: @project)
    error2 = create_error_group(project: @project)

    create_error_event(error_group: error1, commit: "abc123")
    create_error_event(error_group: error2, commit: "def456")

    result = @tool.call(commit: "abc123")

    error_ids = result[:errors].map { |e| e[:id] }
    assert_includes error_ids, error1.id
    refute_includes error_ids, error2.id
  end

  test "combines multiple filters" do
    error1 = create_error_group(project: @project, error_class: "NoMethodError")
    error2 = create_error_group(project: @project, error_class: "NoMethodError")
    error3 = create_error_group(project: @project, error_class: "ArgumentError")

    create_error_event(error_group: error1, user_id: "user_123")
    create_error_event(error_group: error2, user_id: "user_456")
    create_error_event(error_group: error3, user_id: "user_123")

    result = @tool.call(error_class: "NoMethodError", user_id: "user_123")

    assert_equal 1, result[:count]
    assert_equal error1.id, result[:errors].first[:id]
  end

  test "limits results to 20" do
    25.times { create_error_group(project: @project) }

    result = @tool.call({})

    assert_equal 20, result[:errors].length
  end

  test "formats errors correctly" do
    error = create_error_group(
      project: @project,
      error_class: "NoMethodError",
      message: "undefined method 'foo' for nil:NilClass",
      event_count: 42
    )

    result = @tool.call({})
    formatted = result[:errors].first

    assert_equal error.id, formatted[:id]
    assert_equal "NoMethodError", formatted[:error_class]
    assert formatted[:message].present?
    assert_equal 42, formatted[:event_count]
  end

  test "returns count in response" do
    3.times { create_error_group(project: @project) }

    result = @tool.call({})

    assert_equal 3, result[:count]
  end

  test "returns sorted by recent" do
    old = create_error_group(project: @project, last_seen_at: 2.days.ago)
    new = create_error_group(project: @project, last_seen_at: 1.hour.ago)

    result = @tool.call({})

    assert_equal new.id, result[:errors].first[:id]
  end

  test "has correct DESCRIPTION" do
    assert Mcp::Tools::ReflexSearch::DESCRIPTION.present?
    assert Mcp::Tools::ReflexSearch::DESCRIPTION.downcase.include?("search")
  end

  test "has correct SCHEMA" do
    schema = Mcp::Tools::ReflexSearch::SCHEMA

    assert_equal "object", schema[:type]
    assert schema[:properties][:query].present?
    assert schema[:properties][:error_class].present?
    assert schema[:properties][:user_id].present?
    assert schema[:properties][:commit].present?
    assert schema[:properties][:since].present?
  end
end
