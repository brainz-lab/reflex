# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::ReflexListTest < ActiveSupport::TestCase
  setup do
    @project = create_project
    @tool = Mcp::Tools::ReflexList.new(@project)
  end

  test "returns empty list when no errors exist" do
    result = @tool.call({})

    assert_equal [], result[:errors]
    assert_equal 0, result[:count]
  end

  test "returns unresolved errors by default" do
    unresolved = create_error_group(project: @project, status: "unresolved")
    resolved = create_error_group(project: @project, status: "resolved")
    ignored = create_error_group(project: @project, status: "ignored")

    result = @tool.call({})

    error_ids = result[:errors].map { |e| e[:id] }
    assert_includes error_ids, unresolved.id
    refute_includes error_ids, resolved.id
    refute_includes error_ids, ignored.id
  end

  test "filters by resolved status" do
    unresolved = create_error_group(project: @project, status: "unresolved")
    resolved = create_error_group(project: @project, status: "resolved")

    result = @tool.call(status: "resolved")

    error_ids = result[:errors].map { |e| e[:id] }
    assert_includes error_ids, resolved.id
    refute_includes error_ids, unresolved.id
  end

  test "filters by ignored status" do
    unresolved = create_error_group(project: @project, status: "unresolved")
    ignored = create_error_group(project: @project, status: "ignored")

    result = @tool.call(status: "ignored")

    error_ids = result[:errors].map { |e| e[:id] }
    assert_includes error_ids, ignored.id
    refute_includes error_ids, unresolved.id
  end

  test "returns all errors when status is 'all'" do
    unresolved = create_error_group(project: @project, status: "unresolved")
    resolved = create_error_group(project: @project, status: "resolved")
    ignored = create_error_group(project: @project, status: "ignored")

    result = @tool.call(status: "all")

    error_ids = result[:errors].map { |e| e[:id] }
    assert_includes error_ids, unresolved.id
    assert_includes error_ids, resolved.id
    assert_includes error_ids, ignored.id
  end

  test "sorts by recent by default" do
    old_error = create_error_group(project: @project, last_seen_at: 2.days.ago)
    new_error = create_error_group(project: @project, last_seen_at: 1.hour.ago)

    result = @tool.call(status: "all")

    assert_equal new_error.id, result[:errors].first[:id]
  end

  test "sorts by frequent when specified" do
    few_occurrences = create_error_group(project: @project, event_count: 5)
    many_occurrences = create_error_group(project: @project, event_count: 100)

    result = @tool.call(status: "all", sort: "frequent")

    assert_equal many_occurrences.id, result[:errors].first[:id]
  end

  test "limits results to 20 by default" do
    25.times { create_error_group(project: @project) }

    result = @tool.call(status: "all")

    assert_equal 20, result[:errors].length
  end

  test "respects custom limit" do
    10.times { create_error_group(project: @project) }

    result = @tool.call(status: "all", limit: 5)

    assert_equal 5, result[:errors].length
  end

  test "formats error correctly" do
    error = create_error_group(
      project: @project,
      error_class: "NoMethodError",
      message: "undefined method 'foo' for nil:NilClass",
      file_path: "app/models/user.rb",
      line_number: 42,
      function_name: "full_name",
      event_count: 10,
      last_commit: "abc123"
    )

    result = @tool.call(status: "all")
    formatted = result[:errors].first

    assert_equal error.id, formatted[:id]
    assert_equal "NoMethodError", formatted[:error_class]
    assert formatted[:message].present?
    assert formatted[:location].present?
    assert_equal "unresolved", formatted[:status]
    assert_equal 10, formatted[:event_count]
  end

  test "has correct DESCRIPTION" do
    assert Mcp::Tools::ReflexList::DESCRIPTION.present?
    assert Mcp::Tools::ReflexList::DESCRIPTION.include?("errors")
  end

  test "has correct SCHEMA" do
    schema = Mcp::Tools::ReflexList::SCHEMA

    assert_equal "object", schema[:type]
    assert schema[:properties][:status].present?
    assert schema[:properties][:sort].present?
    assert schema[:properties][:limit].present?
  end
end
