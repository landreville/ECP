# MCP (Model Context Protocol) Server Controller
#
# Implements the MCP Streamable HTTP transport (2024-11-05 spec):
#   POST /mcp  - Client sends JSON-RPC messages; server responds inline
#   GET  /mcp/sse - Server-Sent Events stream for server-initiated messages
#
# Authentication: Bearer token in Authorization header
class McpController < ApplicationController
  # Sessions are managed per MCP session-id header
  before_action :resolve_mcp_session, except: [:sse]

  # POST /mcp
  def handle
    body = request.body.read

    begin
      message = JSON.parse(body)
    rescue JSON::ParserError
      render json: Mcp::Protocol.parse_error, status: :bad_request
      return
    end

    server   = Mcp::Server.new(@mcp_session)
    response_data = server.handle(message)

    # Touch session activity
    @mcp_session.touch_activity!

    if response_data.nil?
      # Notification — no content response
      head :accepted
    else
      render json: response_data
    end
  end

  # GET /mcp/sse
  # Server-Sent Events stream (for server-initiated messages / progress)
  def sse
    # SSE streams are authenticated the same way
    response.headers["Content-Type"]  = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    session_id = request.headers["Mcp-Session-Id"]

    response.stream.write("event: endpoint\n")
    response.stream.write("data: #{mcp_endpoint_url}\n\n")

    # Keep-alive loop; real implementations would push notifications here
    loop do
      sleep 30
      response.stream.write(": keep-alive\n\n")
    end
  rescue ActionController::Live::ClientDisconnected, IOError
    # Client disconnected — normal
  ensure
    response.stream.close
  end

  # DELETE /mcp/session
  def delete_session
    @mcp_session.destroy
    head :no_content
  end

  private

  def resolve_mcp_session
    session_id = request.headers["Mcp-Session-Id"]

    if session_id.present?
      @mcp_session = McpSession.active.find_by(
        session_id: session_id,
        api_client: current_client
      )

      unless @mcp_session
        render json: { error: "Session not found or expired" }, status: :not_found
        return
      end
    else
      # No session id — create a new one (will be finalized on initialize)
      @mcp_session = McpSession.create!(
        api_client: current_client,
        session_id: SecureRandom.uuid,
        last_active_at: Time.current,
        expires_at: McpSession::SESSION_TTL.from_now
      )
      response.headers["Mcp-Session-Id"] = @mcp_session.session_id
    end
  end
end
