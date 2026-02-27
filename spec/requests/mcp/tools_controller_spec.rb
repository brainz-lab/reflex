# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mcp::ToolsController", type: :request do
  let!(:project) { create(:project, platform_project_id: "prj_test123") }
  let(:api_key) { "valid_key" }
  let(:auth_headers) { { "Authorization" => "Bearer #{api_key}" } }
  let!(:error_group) { create(:error_group, project: project) }

  describe "authentication" do
    it "requires authentication for index" do
      get mcp_tools_url, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Invalid API key")
    end

    it "requires authentication for call" do
      post "/mcp/tools/reflex_list", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "requires authentication for rpc" do
      post mcp_rpc_url, params: { method: "tools/list" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts Bearer token authentication" do
      get mcp_tools_url, headers: auth_headers, as: :json
      expect(response).to have_http_status(:success)
    end

    it "accepts X-API-Key authentication" do
      get mcp_tools_url, headers: { "X-API-Key" => api_key }, as: :json
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /mcp/tools" do
    it "returns list of all tools" do
      get mcp_tools_url, headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["tools"]).to be_an(Array)
      expect(json["tools"].length).to be > 0

      tool_names = json["tools"].map { |t| t["name"] }
      expect(tool_names).to include("reflex_list", "reflex_show", "reflex_resolve",
        "reflex_ignore", "reflex_unresolve", "reflex_stats", "reflex_search", "reflex_events")
    end

    it "returns tool schemas" do
      get mcp_tools_url, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      list_tool = json["tools"].find { |t| t["name"] == "reflex_list" }

      expect(list_tool["description"]).to be_present
      expect(list_tool["inputSchema"]).to be_present
      expect(list_tool["inputSchema"]["type"]).to eq("object")
    end
  end

  describe "POST /mcp/tools/:name" do
    it "invokes reflex_list tool" do
      post "/mcp/tools/reflex_list",
        params: { status: "unresolved" },
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["errors"]).to be_an(Array)
      expect(json["count"]).to be_an(Integer)
    end

    it "invokes reflex_show tool" do
      post "/mcp/tools/reflex_show",
        params: { error_id: error_group.id },
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["error"]).to be_present
      expect(json["error"]["id"]).to eq(error_group.id)
    end

    it "invokes reflex_resolve tool" do
      post "/mcp/tools/reflex_resolve",
        params: { error_id: error_group.id },
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["resolved"]).to be true
      expect(json["error_id"]).to eq(error_group.id)

      error_group.reload
      expect(error_group.status).to eq("resolved")
    end

    it "invokes reflex_stats tool" do
      post "/mcp/tools/reflex_stats",
        params: { since: "24h" },
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key("total_errors")
      expect(json).to have_key("unresolved")
      expect(json).to have_key("resolved")
      expect(json).to have_key("ignored")
    end

    it "returns error for unknown tool" do
      post "/mcp/tools/unknown_tool", headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Unknown tool")
    end

    it "returns error for nonexistent error_id" do
      post "/mcp/tools/reflex_show",
        params: { error_id: "nonexistent-id" },
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Error not found")
    end
  end

  describe "POST /mcp/rpc (JSON-RPC)" do
    it "tools/list returns all tools" do
      post mcp_rpc_url,
        params: { jsonrpc: "2.0", id: 1, method: "tools/list" },
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["jsonrpc"]).to eq("2.0")
      expect(json["id"]).to eq(1)
      expect(json["result"]["tools"]).to be_an(Array)
      expect(json["result"]["tools"].length).to be > 0
    end

    it "tools/call invokes tool" do
      post mcp_rpc_url,
        params: {
          jsonrpc: "2.0",
          id: 2,
          method: "tools/call",
          params: { name: "reflex_list", arguments: { status: "all" } }
        },
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["jsonrpc"]).to eq("2.0")
      expect(json["id"]).to eq(2)
      expect(json["result"]["content"]).to be_an(Array)
      expect(json["result"]["content"][0]["type"]).to eq("text")

      content = JSON.parse(json["result"]["content"][0]["text"])
      expect(content["errors"]).to be_an(Array)
    end

    it "returns error for unknown method" do
      post mcp_rpc_url,
        params: { jsonrpc: "2.0", id: 3, method: "unknown/method" },
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["jsonrpc"]).to eq("2.0")
      expect(json["id"]).to eq(3)
      expect(json["error"]).to be_present
      expect(json["error"]["code"]).to eq(-32601)
      expect(json["error"]["message"]).to include("Unknown method")
    end

    it "returns error when tool call fails" do
      post mcp_rpc_url,
        params: {
          jsonrpc: "2.0",
          id: 4,
          method: "tools/call",
          params: { name: "nonexistent_tool", arguments: {} }
        },
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq(-32603)
    end

    it "preserves request id in response" do
      post mcp_rpc_url,
        params: { jsonrpc: "2.0", id: "custom-id-123", method: "tools/list" },
        headers: auth_headers,
        as: :json

      json = JSON.parse(response.body)
      expect(json["id"]).to eq("custom-id-123")
    end
  end
end
