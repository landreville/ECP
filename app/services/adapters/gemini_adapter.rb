module Adapters
  # Google Gemini adapter — uses the gemini-cli tool or direct Gemini API.
  # Falls back to gemini-cli subprocess if configured, otherwise uses the REST API via Faraday.
  class GeminiAdapter < BaseAdapter
    GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta".freeze

    def tools
      [
        build_tool(
          name: "generate_content",
          description: "Generate text content using Google Gemini",
          input_schema: {
            type: "object",
            properties: {
              prompt:      { type: "string", description: "The prompt to send to Gemini" },
              model:       { type: "string", description: "Gemini model (default: gemini-1.5-flash)" },
              temperature: { type: "number", description: "Sampling temperature 0.0-2.0 (default: 1.0)" },
              max_tokens:  { type: "integer", description: "Maximum output tokens (default: 8192)" }
            },
            required: ["prompt"]
          }
        ) { |args| generate_content(args) },

        build_tool(
          name: "list_models",
          description: "List available Gemini models",
          input_schema: {
            type: "object",
            properties: {}
          }
        ) { |_args| list_models }
      ]
    end

    def test_connection
      cred_hash = @credential&.credential_hash || {}
      api_key   = cred_hash["api_key"]

      if use_gemini_cli?
        test_via_cli
      elsif api_key.present?
        test_via_api(api_key)
      else
        { success: false, message: "No API key or gemini-cli configured" }
      end
    end

    private

    def use_gemini_cli?
      config["use_cli"] == true
    end

    def gemini_cli_path
      config["cli_path"] || "gemini"
    end

    def api_key
      @credential&.credential_hash&.dig("api_key")
    end

    def default_model
      config["default_model"] || "gemini-1.5-flash"
    end

    def generate_content(args)
      prompt      = args["prompt"]
      model       = args["model"] || default_model
      temperature = args["temperature"]&.to_f || 1.0
      max_tokens  = args["max_tokens"]&.to_i || 8192

      if use_gemini_cli?
        generate_via_cli(prompt, model)
      else
        generate_via_api(prompt, model, temperature, max_tokens)
      end
    end

    def generate_via_cli(prompt, model)
      cli = gemini_cli_path

      # Sanitize inputs to prevent shell injection — use Open3 with argument array
      require "open3"
      cmd = [cli, "--model", model, prompt]
      stdout, stderr, status = Open3.capture3(*cmd)

      if status.success?
        stdout.strip
      else
        "Gemini CLI error: #{stderr.strip}"
      end
    rescue Errno::ENOENT
      "gemini-cli not found at '#{cli}'. Install gemini-cli or configure use_cli: false."
    rescue => e
      "Gemini CLI error: #{e.message}"
    end

    def generate_via_api(prompt, model, temperature, max_tokens)
      conn     = api_http_connection
      endpoint = "/models/#{model}:generateContent?key=#{api_key}"

      payload = {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: temperature,
          maxOutputTokens: max_tokens
        }
      }

      response = conn.post(endpoint) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = payload.to_json
      end

      data = JSON.parse(response.body)
      data.dig("candidates", 0, "content", "parts", 0, "text") ||
        "No content in response"
    rescue Faraday::Error => e
      "Gemini API error: #{e.message}"
    rescue JSON::ParserError => e
      "Error parsing Gemini response: #{e.message}"
    end

    def list_models
      if use_gemini_cli?
        return "Use the Gemini API directly to list models (cli mode active)"
      end

      conn     = api_http_connection
      response = conn.get("/models?key=#{api_key}")
      data     = JSON.parse(response.body)

      models = data["models"] || []
      models.map { |m| "#{m['name']} - #{m['displayName']}" }.join("\n")
    rescue => e
      "Error listing models: #{e.message}"
    end

    def test_via_cli
      require "open3"
      _out, _err, status = Open3.capture3(gemini_cli_path, "--version")
      if status.success?
        { success: true, message: "gemini-cli is available" }
      else
        { success: false, message: "gemini-cli returned error" }
      end
    rescue Errno::ENOENT
      { success: false, message: "gemini-cli not found" }
    end

    def test_via_api(api_key)
      conn = api_http_connection
      conn.get("/models?key=#{api_key}")
      { success: true, message: "Gemini API connection successful" }
    rescue => e
      { success: false, message: e.message }
    end

    def api_http_connection
      Faraday.new(url: GEMINI_API_BASE) do |f|
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end
  end
end
