module Mcp
  # Registry that aggregates tools from all enabled service adapters
  class ToolRegistry
    attr_reader :tools

    def initialize(api_client)
      @api_client = api_client
      @tools = {}
      load_tools_from_services
    end

    def list
      @tools.values.map(&:to_mcp_definition)
    end

    def call(tool_name, arguments)
      tool = @tools[tool_name]
      raise ArgumentError, "Unknown tool: #{tool_name}" unless tool

      tool.call(arguments)
    end

    private

    def load_tools_from_services
      Service.enabled.each do |service|
        next unless @api_client.allowed_service?(service.name)

        adapter = service.build_adapter
        adapter.tools.each do |tool|
          @tools[tool.name] = tool
        end
      rescue => e
        Rails.logger.error("Failed to load tools from service #{service.name}: #{e.message}")
      end
    end
  end
end
