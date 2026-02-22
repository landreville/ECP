module Adapters
  # Base class for all service adapters.
  # Subclasses define #tools (returns Array<Mcp::Tool>) and #test_connection.
  class BaseAdapter
    attr_reader :service, :credential

    def initialize(service, credential = nil)
      @service    = service
      @credential = credential
    end

    # Returns an Array<Mcp::Tool>
    def tools
      raise NotImplementedError, "#{self.class} must implement #tools"
    end

    # Returns { success: bool, message: string }
    def test_connection
      raise NotImplementedError, "#{self.class} must implement #test_connection"
    end

    protected

    def config
      @service.config || {}
    end

    # Build an authenticated Faraday connection to the service base URL
    def http_connection(base_url = nil)
      url = base_url || @service.base_url
      cred_hash = @credential&.credential_hash || {}

      Faraday.new(url: url) do |f|
        case @credential&.credential_type
        when "basic_auth"
          f.request :authorization, :basic, cred_hash["username"], cred_hash["password"]
        when "bearer_token"
          f.request :authorization, "Bearer", cred_hash["token"]
        when "api_key"
          # API key goes in a header; header name is in config["api_key_header"]
          key_header = config["api_key_header"] || "X-Api-Key"
          f.headers[key_header] = cred_hash["api_key"]
        end

        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    def build_tool(name:, description:, input_schema:, &handler)
      Mcp::Tool.new(
        name: "#{service.name}__#{name}",
        description: description,
        input_schema: input_schema,
        &handler
      )
    end
  end
end
