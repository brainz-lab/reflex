# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::ReflexIgnoreTest < ActiveSupport::TestCase
  setup do
    @project = create_project
    @tool = Mcp::Tools::ReflexIgnore.new(@project)
  end

  test "ignores an unresolved error" do
    error = create_error_group(project: @project, status: "unresolved")

    result = @tool.call(error_id: error.id)

    assert result[:ignored]
    assert_equal error.id, result[:error_id]

    error.reload
    assert_equal "ignored", error.status
  end

  test "returns error class in response" do
    error = create_error_group(project: @project, error_class: "ArgumentError")

    result = @tool.call(error_id: error.id)

    assert_equal "ArgumentError", result[:error_class]
  end

  test "can ignore a resolved error" do
    error = create_error_group(project: @project, status: "resolved")

    result = @tool.call(error_id: error.id)

    assert result[:ignored]
    error.reload
    assert_equal "ignored", error.status
  end

  test "can ignore an already ignored error" do
    error = create_error_group(project: @project, status: "ignored")

    result = @tool.call(error_id: error.id)

    assert result[:ignored]
    error.reload
    assert_equal "ignored", error.status
  end

  test "returns error message for nonexistent error" do
    result = @tool.call(error_id: "nonexistent-uuid")

    assert_equal "Error not found", result[:error]
    refute result[:ignored]
  end

  test "cannot ignore error from different project" do
    other_project = create_project
    other_error = create_error_group(project: other_project)

    result = @tool.call(error_id: other_error.id)

    assert_equal "Error not found", result[:error]
    other_error.reload
    assert_equal "unresolved", other_error.status
  end

  test "has correct DESCRIPTION" do
    assert Mcp::Tools::ReflexIgnore::DESCRIPTION.present?
    assert Mcp::Tools::ReflexIgnore::DESCRIPTION.downcase.include?("ignore")
  end

  test "has correct SCHEMA with required error_id" do
    schema = Mcp::Tools::ReflexIgnore::SCHEMA

    assert_equal "object", schema[:type]
    assert schema[:properties][:error_id].present?
    assert_includes schema[:required], "error_id"
  end
end
