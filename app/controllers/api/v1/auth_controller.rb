module Api
  module V1
    # Token issuance endpoint.
    # ECP uses pre-shared API keys (bearer tokens) rather than username/password.
    # This endpoint validates the token and returns metadata about the client.
    class AuthController < ApplicationController
      # POST /api/v1/auth/token
      def token
        # current_client is set by ApplicationController#authenticate_api_client!
        render json: {
          client: {
            id: current_client.id,
            name: current_client.name,
            allowed_services: current_client.allowed_services
          },
          authenticated_at: Time.current.iso8601
        }
      end

      # POST /api/v1/auth/refresh
      # No-op for bearer-token auth (tokens don't expire); provided for protocol compatibility.
      def refresh
        render json: { message: "Bearer tokens do not expire. Re-use your existing token." }
      end
    end
  end
end
