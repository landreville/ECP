module Mcp
  # MCP Protocol constants and helpers (MCP spec 2024-11-05)
  module Protocol
    PROTOCOL_VERSION = "2024-11-05"

    # JSON-RPC 2.0 error codes
    module ErrorCodes
      PARSE_ERROR      = -32700
      INVALID_REQUEST  = -32600
      METHOD_NOT_FOUND = -32601
      INVALID_PARAMS   = -32602
      INTERNAL_ERROR   = -32603

      # MCP-specific error codes
      NOT_INITIALIZED  = -32002
      ALREADY_INITIALIZED = -32003
    end

    def self.success_response(id, result)
      { jsonrpc: "2.0", id: id, result: result }
    end

    def self.error_response(id, code, message, data = nil)
      err = { code: code, message: message }
      err[:data] = data if data
      { jsonrpc: "2.0", id: id, error: err }
    end

    def self.notification(method, params = nil)
      msg = { jsonrpc: "2.0", method: method }
      msg[:params] = params if params
      msg
    end

    def self.parse_error(id = nil)
      error_response(id, ErrorCodes::PARSE_ERROR, "Parse error")
    end

    def self.invalid_request(id = nil)
      error_response(id, ErrorCodes::INVALID_REQUEST, "Invalid Request")
    end

    def self.method_not_found(id, method)
      error_response(id, ErrorCodes::METHOD_NOT_FOUND, "Method not found: #{method}")
    end

    def self.internal_error(id, detail = nil)
      error_response(id, ErrorCodes::INTERNAL_ERROR, "Internal error", detail)
    end

    def self.not_initialized(id)
      error_response(id, ErrorCodes::NOT_INITIALIZED, "Server not initialized")
    end
  end
end
