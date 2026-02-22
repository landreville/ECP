module Mcp
  # Handles MCP JSON-RPC 2.0 message dispatch for a given session
  class Server
    SERVER_INFO = {
      name: "everything-control-plane",
      version: Rails.application.config.x.ecp_version || "0.1.0"
    }.freeze

    SERVER_CAPABILITIES = {
      tools: { listChanged: true },
      resources: {},
      prompts: {}
    }.freeze

    def initialize(mcp_session)
      @session = mcp_session
      @initialized = mcp_session.protocol_version.present?
    end

    # Process a single JSON-RPC message and return the response hash (or nil for notifications)
    def handle(message)
      id     = message["id"]
      method = message["method"]
      params = message["params"] || {}

      # Notifications (no id) are fire-and-forget
      return nil unless id

      unless method
        return Protocol.invalid_request(id)
      end

      if method == "initialize"
        handle_initialize(id, params)
      elsif !@initialized
        Protocol.not_initialized(id)
      else
        dispatch(id, method, params)
      end
    rescue JSON::ParserError
      Protocol.parse_error
    rescue => e
      Rails.logger.error("MCP server error: #{e.class} #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      Protocol.internal_error(id, e.message)
    end

    private

    def handle_initialize(id, params)
      protocol_version = params["protocolVersion"] || Protocol::PROTOCOL_VERSION
      client_info      = params["clientInfo"] || {}

      @session.update!(
        protocol_version: protocol_version,
        client_info: client_info,
        server_capabilities: SERVER_CAPABILITIES
      )
      @initialized = true

      Protocol.success_response(id, {
        protocolVersion: Protocol::PROTOCOL_VERSION,
        capabilities: SERVER_CAPABILITIES,
        serverInfo: SERVER_INFO
      })
    end

    def dispatch(id, method, params)
      case method
      when "ping"
        Protocol.success_response(id, {})
      when "tools/list"
        handle_tools_list(id, params)
      when "tools/call"
        handle_tools_call(id, params)
      when "resources/list"
        Protocol.success_response(id, { resources: [] })
      when "prompts/list"
        Protocol.success_response(id, { prompts: [] })
      else
        Protocol.method_not_found(id, method)
      end
    end

    def handle_tools_list(id, _params)
      registry = ToolRegistry.new(@session.api_client)
      Protocol.success_response(id, { tools: registry.list })
    rescue => e
      Protocol.internal_error(id, e.message)
    end

    def handle_tools_call(id, params)
      tool_name  = params["name"]
      arguments  = params["arguments"] || {}

      unless tool_name.present?
        return Protocol.error_response(id, Protocol::ErrorCodes::INVALID_PARAMS, "Missing tool name")
      end

      registry = ToolRegistry.new(@session.api_client)
      result   = registry.call(tool_name, arguments)

      Protocol.success_response(id, {
        content: [{ type: "text", text: result.to_s }]
      })
    rescue ArgumentError => e
      Protocol.error_response(id, Protocol::ErrorCodes::INVALID_PARAMS, e.message)
    rescue Mcp::ToolError => e
      Protocol.error_response(id, Protocol::ErrorCodes::INTERNAL_ERROR, e.message)
    rescue => e
      Protocol.internal_error(id, e.message)
    end
  end
end
