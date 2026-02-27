# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mcp::Server, type: :service do
  let(:project) { create(:project) }
  let(:server) { described_class.new(project) }

  describe "#initialize" do
    it "initializes with project" do
      expect(server.instance_variable_get(:@project)).to eq(project)
    end
  end

  describe "#list_tools" do
    it "returns all registered tools" do
      tools = server.list_tools

      expect(tools).to be_an(Array)
      expect(tools.length).to eq(8)

      tool_names = tools.map { |t| t[:name] }
      expect(tool_names).to include(
        "reflex_list", "reflex_show", "reflex_resolve",
        "reflex_ignore", "reflex_unresolve", "reflex_stats",
        "reflex_search", "reflex_events"
      )
    end

    it "returns description and schema for each tool" do
      tools = server.list_tools

      tools.each do |tool|
        expect(tool[:name]).to be_present
        expect(tool[:description]).to be_present
        expect(tool[:inputSchema]).to be_present
        expect(tool[:inputSchema][:type]).to eq("object")
      end
    end
  end

  describe "#call_tool" do
    it "invokes correct tool class" do
      create(:error_group, project: project)

      result = server.call_tool("reflex_list", { status: "all" })

      expect(result[:errors]).to be_an(Array)
      expect(result[:count]).to be_an(Integer)
    end

    it "passes arguments to tool" do
      error_group = create(:error_group, project: project)

      result = server.call_tool("reflex_show", { error_id: error_group.id })

      expect(result[:error]).to be_present
      expect(result[:error][:id]).to eq(error_group.id)
    end

    it "raises error for unknown tool" do
      expect {
        server.call_tool("unknown_tool", {})
      }.to raise_error(RuntimeError, "Unknown tool: unknown_tool")
    end

    it "symbolizes string keys in arguments" do
      error_group = create(:error_group, project: project)

      result = server.call_tool("reflex_show", { "error_id" => error_group.id })
      expect(result[:error]).to be_present
    end

    it "handles empty arguments" do
      result = server.call_tool("reflex_list", {})
      expect(result[:errors]).to be_an(Array)
    end
  end

  describe "TOOLS constant" do
    it "is frozen" do
      expect(Mcp::Server::TOOLS).to be_frozen
    end
  end
end
