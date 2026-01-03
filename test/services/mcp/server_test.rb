# frozen_string_literal: true

require "test_helper"

class Mcp::ServerTest < ActiveSupport::TestCase
  setup do
    @project = create_project
    @server = Mcp::Server.new(@project)
  end

  test "initializes with project" do
    assert_equal @project, @server.instance_variable_get(:@project)
  end

  test "list_tools returns all registered tools" do
    tools = @server.list_tools

    assert tools.is_a?(Array)
    assert_equal 8, tools.length

    tool_names = tools.map { |t| t[:name] }
    assert_includes tool_names, "reflex_list"
    assert_includes tool_names, "reflex_show"
    assert_includes tool_names, "reflex_resolve"
    assert_includes tool_names, "reflex_ignore"
    assert_includes tool_names, "reflex_unresolve"
    assert_includes tool_names, "reflex_stats"
    assert_includes tool_names, "reflex_search"
    assert_includes tool_names, "reflex_events"
  end

  test "list_tools returns description and schema for each tool" do
    tools = @server.list_tools

    tools.each do |tool|
      assert tool[:name].present?, "Tool should have a name"
      assert tool[:description].present?, "Tool #{tool[:name]} should have a description"
      assert tool[:inputSchema].present?, "Tool #{tool[:name]} should have an input schema"
      assert_equal "object", tool[:inputSchema][:type], "Tool #{tool[:name]} schema should be object type"
    end
  end

  test "call_tool invokes correct tool class" do
    error_group = create_error_group(project: @project)

    result = @server.call_tool("reflex_list", { status: "all" })

    assert result[:errors].is_a?(Array)
    assert result[:count].is_a?(Integer)
  end

  test "call_tool passes arguments to tool" do
    error_group = create_error_group(project: @project)

    result = @server.call_tool("reflex_show", { error_id: error_group.id })

    assert result[:error].present?
    assert_equal error_group.id, result[:error][:id]
  end

  test "call_tool raises error for unknown tool" do
    error = assert_raises(RuntimeError) do
      @server.call_tool("unknown_tool", {})
    end

    assert_equal "Unknown tool: unknown_tool", error.message
  end

  test "call_tool symbolizes string keys in arguments" do
    error_group = create_error_group(project: @project)

    result = @server.call_tool("reflex_show", { "error_id" => error_group.id })

    assert result[:error].present?
  end

  test "call_tool handles empty arguments" do
    result = @server.call_tool("reflex_list", {})

    assert result[:errors].is_a?(Array)
  end

  test "TOOLS constant is frozen" do
    assert Mcp::Server::TOOLS.frozen?
  end
end
