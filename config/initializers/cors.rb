Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "*")

    resource "/mcp*",
      headers: :any,
      methods: [:get, :post, :delete, :options],
      expose: ["Mcp-Session-Id"]

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options]
  end
end
