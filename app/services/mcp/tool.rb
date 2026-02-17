module Mcp
  # Represents a single MCP tool
  class Tool
    attr_reader :name, :description, :input_schema

    def initialize(name:, description:, input_schema:, &handler)
      @name = name
      @description = description
      @input_schema = input_schema
      @handler = handler
    end

    def call(arguments)
      @handler.call(arguments)
    rescue => e
      raise Mcp::ToolError.new(e.message)
    end

    def to_mcp_definition
      {
        name: @name,
        description: @description,
        inputSchema: @input_schema
      }
    end
  end

  class ToolError < StandardError; end
end
