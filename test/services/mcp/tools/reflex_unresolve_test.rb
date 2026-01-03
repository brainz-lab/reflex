# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::ReflexUnresolveTest < ActiveSupport::TestCase
  setup do
    @project = create_project
    @tool = Mcp::Tools::ReflexUnresolve.new(@project)
  end

  test "unresolves a resolved error" do
    error = create_error_group(project: @project, status: "resolved")

    result = @tool.call(error_id: error.id)

    assert result[:unresolved]
    assert_equal error.id, result[:error_id]

    error.reload
    assert_equal "unresolved", error.status
  end

  test "returns error class in response" do
    error = create_error_group(project: @project, status: "resolved", error_class: "RuntimeError")

    result = @tool.call(error_id: error.id)

    assert_equal "RuntimeError", result[:error_class]
  end

  test "can unresolve an ignored error" do
    error = create_error_group(project: @project, status: "ignored")

    result = @tool.call(error_id: error.id)

    assert result[:unresolved]
    error.reload
    assert_equal "unresolved", error.status
  end

  test "can unresolve an already unresolved error" do
    error = create_error_group(project: @project, status: "unresolved")

    result = @tool.call(error_id: error.id)

    assert result[:unresolved]
    error.reload
    assert_equal "unresolved", error.status
  end

  test "clears resolved_at and resolved_by" do
    error = create_error_group(project: @project, status: "resolved")
    error.update!(resolved_at: Time.current, resolved_by: "user_123")

    @tool.call(error_id: error.id)

    error.reload
    assert_nil error.resolved_at
    assert_nil error.resolved_by
  end

  test "returns error message for nonexistent error" do
    result = @tool.call(error_id: "nonexistent-uuid")

    assert_equal "Error not found", result[:error]
    refute result[:unresolved]
  end

  test "cannot unresolve error from different project" do
    other_project = create_project
    other_error = create_error_group(project: other_project, status: "resolved")

    result = @tool.call(error_id: other_error.id)

    assert_equal "Error not found", result[:error]
    other_error.reload
    assert_equal "resolved", other_error.status
  end

  test "has correct DESCRIPTION" do
    assert Mcp::Tools::ReflexUnresolve::DESCRIPTION.present?
    assert Mcp::Tools::ReflexUnresolve::DESCRIPTION.downcase.include?("unresolved")
  end

  test "has correct SCHEMA with required error_id" do
    schema = Mcp::Tools::ReflexUnresolve::SCHEMA

    assert_equal "object", schema[:type]
    assert schema[:properties][:error_id].present?
    assert_includes schema[:required], "error_id"
  end
end
