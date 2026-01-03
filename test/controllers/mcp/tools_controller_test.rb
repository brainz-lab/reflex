# frozen_string_literal: true

require "test_helper"

class Mcp::ToolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = create_project(platform_project_id: "prj_test123")
    @api_key = "valid_key"
    @error_group = create_error_group(project: @project)
  end

  # Authentication tests

  test "requires authentication for index" do
    get mcp_tools_url, as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Invalid API key", json["error"]
  end

  test "requires authentication for call" do
    post "/mcp/tools/reflex_list", as: :json

    assert_response :unauthorized
  end

  test "requires authentication for rpc" do
    post mcp_rpc_url, params: { method: "tools/list" }, as: :json

    assert_response :unauthorized
  end

  test "accepts Bearer token authentication" do
    get mcp_tools_url,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
  end

  test "accepts X-API-Key authentication" do
    get mcp_tools_url,
      headers: { "X-API-Key" => @api_key },
      as: :json

    assert_response :success
  end

  # Index endpoint tests

  test "index returns list of all tools" do
    get mcp_tools_url,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["tools"].is_a?(Array)
    assert json["tools"].length > 0

    tool_names = json["tools"].map { |t| t["name"] }
    assert_includes tool_names, "reflex_list"
    assert_includes tool_names, "reflex_show"
    assert_includes tool_names, "reflex_resolve"
    assert_includes tool_names, "reflex_ignore"
    assert_includes tool_names, "reflex_unresolve"
    assert_includes tool_names, "reflex_stats"
    assert_includes tool_names, "reflex_search"
    assert_includes tool_names, "reflex_events"
  end

  test "index returns tool schemas" do
    get mcp_tools_url,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    list_tool = json["tools"].find { |t| t["name"] == "reflex_list" }

    assert list_tool["description"].present?
    assert list_tool["inputSchema"].present?
    assert_equal "object", list_tool["inputSchema"]["type"]
  end

  # Call endpoint tests

  test "call invokes reflex_list tool" do
    post "/mcp/tools/reflex_list",
      params: { status: "unresolved" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["errors"].is_a?(Array)
    assert json["count"].is_a?(Integer)
  end

  test "call invokes reflex_show tool" do
    post "/mcp/tools/reflex_show",
      params: { error_id: @error_group.id },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["error"].present?
    assert_equal @error_group.id, json["error"]["id"]
  end

  test "call invokes reflex_resolve tool" do
    post "/mcp/tools/reflex_resolve",
      params: { error_id: @error_group.id },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["resolved"]
    assert_equal @error_group.id, json["error_id"]

    @error_group.reload
    assert_equal "resolved", @error_group.status
  end

  test "call invokes reflex_stats tool" do
    post "/mcp/tools/reflex_stats",
      params: { since: "24h" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json.key?("total_errors")
    assert json.key?("unresolved")
    assert json.key?("resolved")
    assert json.key?("ignored")
  end

  test "call returns error for unknown tool" do
    post "/mcp/tools/unknown_tool",
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["error"].include?("Unknown tool")
  end

  test "call returns error for nonexistent error_id" do
    post "/mcp/tools/reflex_show",
      params: { error_id: "nonexistent-id" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Error not found", json["error"]
  end

  # JSON-RPC endpoint tests

  test "rpc tools/list returns all tools" do
    post mcp_rpc_url,
      params: { jsonrpc: "2.0", id: 1, method: "tools/list" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal "2.0", json["jsonrpc"]
    assert_equal 1, json["id"]
    assert json["result"]["tools"].is_a?(Array)
    assert json["result"]["tools"].length > 0
  end

  test "rpc tools/call invokes tool" do
    post mcp_rpc_url,
      params: {
        jsonrpc: "2.0",
        id: 2,
        method: "tools/call",
        params: {
          name: "reflex_list",
          arguments: { status: "all" }
        }
      },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal "2.0", json["jsonrpc"]
    assert_equal 2, json["id"]
    assert json["result"]["content"].is_a?(Array)
    assert_equal "text", json["result"]["content"][0]["type"]

    # Parse the nested JSON result
    content = JSON.parse(json["result"]["content"][0]["text"])
    assert content["errors"].is_a?(Array)
  end

  test "rpc returns error for unknown method" do
    post mcp_rpc_url,
      params: { jsonrpc: "2.0", id: 3, method: "unknown/method" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)

    assert_equal "2.0", json["jsonrpc"]
    assert_equal 3, json["id"]
    assert json["error"].present?
    assert_equal(-32601, json["error"]["code"])
    assert json["error"]["message"].include?("Unknown method")
  end

  test "rpc returns error when tool call fails" do
    post mcp_rpc_url,
      params: {
        jsonrpc: "2.0",
        id: 4,
        method: "tools/call",
        params: {
          name: "nonexistent_tool",
          arguments: {}
        }
      },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)

    assert_equal(-32603, json["error"]["code"])
  end

  test "rpc preserves request id in response" do
    post mcp_rpc_url,
      params: { jsonrpc: "2.0", id: "custom-id-123", method: "tools/list" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    assert_equal "custom-id-123", json["id"]
  end
end
