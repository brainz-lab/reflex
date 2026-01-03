# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::ReflexResolveTest < ActiveSupport::TestCase
  setup do
    @project = create_project
    @tool = Mcp::Tools::ReflexResolve.new(@project)
  end

  test "resolves an unresolved error" do
    error = create_error_group(project: @project, status: "unresolved")

    result = @tool.call(error_id: error.id)

    assert result[:resolved]
    assert_equal error.id, result[:error_id]

    error.reload
    assert_equal "resolved", error.status
  end

  test "returns error class in response" do
    error = create_error_group(project: @project, error_class: "NoMethodError")

    result = @tool.call(error_id: error.id)

    assert_equal "NoMethodError", result[:error_class]
  end

  test "can resolve an ignored error" do
    error = create_error_group(project: @project, status: "ignored")

    result = @tool.call(error_id: error.id)

    assert result[:resolved]
    error.reload
    assert_equal "resolved", error.status
  end

  test "can resolve an already resolved error" do
    error = create_error_group(project: @project, status: "resolved")

    result = @tool.call(error_id: error.id)

    assert result[:resolved]
    error.reload
    assert_equal "resolved", error.status
  end

  test "returns error message for nonexistent error" do
    result = @tool.call(error_id: "nonexistent-uuid")

    assert_equal "Error not found", result[:error]
    refute result[:resolved]
  end

  test "cannot resolve error from different project" do
    other_project = create_project
    other_error = create_error_group(project: other_project)

    result = @tool.call(error_id: other_error.id)

    assert_equal "Error not found", result[:error]
    other_error.reload
    assert_equal "unresolved", other_error.status
  end

  test "has correct DESCRIPTION" do
    assert Mcp::Tools::ReflexResolve::DESCRIPTION.present?
    assert Mcp::Tools::ReflexResolve::DESCRIPTION.downcase.include?("resolved")
  end

  test "has correct SCHEMA with required error_id" do
    schema = Mcp::Tools::ReflexResolve::SCHEMA

    assert_equal "object", schema[:type]
    assert schema[:properties][:error_id].present?
    assert_includes schema[:required], "error_id"
  end
end
