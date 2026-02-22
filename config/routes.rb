Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication
  namespace :api do
    namespace :v1 do
      post "auth/token", to: "auth#token"
      post "auth/refresh", to: "auth#refresh"

      # Service management
      resources :services, except: [:new, :edit] do
        member do
          post :test_connection
        end
      end

      # Credential management
      resources :credentials, except: [:new, :edit]
    end
  end

  # MCP Server endpoint (JSON-RPC 2.0 over HTTP)
  # Supports both streamable HTTP (POST) and SSE (GET) transports
  scope "/mcp" do
    post "/", to: "mcp#handle", as: :mcp_endpoint
    get  "/sse", to: "mcp#sse", as: :mcp_sse
    delete "/session", to: "mcp#delete_session"
  end
end
