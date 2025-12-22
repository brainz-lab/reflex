module Mcp
  class Server
    TOOLS = {
      'reflex_list' => Tools::ReflexList,
      'reflex_show' => Tools::ReflexShow,
      'reflex_events' => Tools::ReflexEvents,
      'reflex_resolve' => Tools::ReflexResolve,
      'reflex_ignore' => Tools::ReflexIgnore,
      'reflex_unresolve' => Tools::ReflexUnresolve,
      'reflex_stats' => Tools::ReflexStats,
      'reflex_search' => Tools::ReflexSearch
    }.freeze

    def initialize(project)
      @project = project
    end

    def list_tools
      TOOLS.map do |name, klass|
        {
          name: name,
          description: klass::DESCRIPTION,
          inputSchema: klass::SCHEMA
        }
      end
    end

    def call_tool(name, arguments = {})
      tool_class = TOOLS[name]
      raise "Unknown tool: #{name}" unless tool_class
      tool_class.new(@project).call(arguments.symbolize_keys)
    end
  end
end
