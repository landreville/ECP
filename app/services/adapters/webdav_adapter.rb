module Adapters
  # WebDAV adapter — exposes file system operations over the MCP tool interface.
  # WebDAV is HTTP-based; we use Faraday with custom HTTP methods.
  class WebdavAdapter < BaseAdapter
    def tools
      [
        build_tool(
          name: "list_directory",
          description: "List files and directories at a WebDAV path",
          input_schema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Directory path (e.g. '/' or '/Documents/')" }
            },
            required: ["path"]
          }
        ) { |args| list_directory(args["path"]) },

        build_tool(
          name: "read_file",
          description: "Read the contents of a file from WebDAV",
          input_schema: {
            type: "object",
            properties: {
              path: { type: "string", description: "File path" }
            },
            required: ["path"]
          }
        ) { |args| read_file(args["path"]) },

        build_tool(
          name: "write_file",
          description: "Write (create or overwrite) a file on WebDAV",
          input_schema: {
            type: "object",
            properties: {
              path:    { type: "string", description: "File path" },
              content: { type: "string", description: "File content" }
            },
            required: ["path", "content"]
          }
        ) { |args| write_file(args["path"], args["content"]) },

        build_tool(
          name: "delete_file",
          description: "Delete a file or directory from WebDAV",
          input_schema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Path to delete" }
            },
            required: ["path"]
          }
        ) { |args| delete_resource(args["path"]) },

        build_tool(
          name: "create_directory",
          description: "Create a directory (MKCOL) on WebDAV",
          input_schema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Directory path to create" }
            },
            required: ["path"]
          }
        ) { |args| create_directory(args["path"]) }
      ]
    end

    def test_connection
      conn = http_connection
      conn.run_request(:propfind, "/", nil, "Depth" => "0", "Content-Type" => "application/xml")
      { success: true, message: "WebDAV connection successful" }
    rescue => e
      { success: false, message: e.message }
    end

    private

    PROPFIND_BODY = <<~XML.freeze
      <?xml version="1.0" encoding="utf-8"?>
      <D:propfind xmlns:D="DAV:">
        <D:prop>
          <D:displayname/>
          <D:resourcetype/>
          <D:getcontentlength/>
          <D:getlastmodified/>
          <D:getcontenttype/>
        </D:prop>
      </D:propfind>
    XML

    def list_directory(path)
      conn = http_connection
      response = conn.run_request(
        :propfind,
        path,
        PROPFIND_BODY,
        "Depth" => "1",
        "Content-Type" => "application/xml"
      )

      parse_propfind_response(response.body, path)
    rescue Faraday::Error => e
      "Error listing directory: #{e.message}"
    end

    def read_file(path)
      conn = http_connection
      response = conn.get(path)
      response.body
    rescue Faraday::Error => e
      "Error reading file: #{e.message}"
    end

    def write_file(path, content)
      conn = http_connection
      conn.put(path) do |req|
        req.body = content
        req.headers["Content-Type"] = "application/octet-stream"
      end
      "File written successfully to #{path}"
    rescue Faraday::Error => e
      "Error writing file: #{e.message}"
    end

    def delete_resource(path)
      conn = http_connection
      conn.delete(path)
      "Deleted #{path}"
    rescue Faraday::Error => e
      "Error deleting: #{e.message}"
    end

    def create_directory(path)
      conn = http_connection
      conn.run_request(:mkcol, path, nil, {})
      "Directory created: #{path}"
    rescue Faraday::Error => e
      "Error creating directory: #{e.message}"
    end

    def parse_propfind_response(xml_body, base_path)
      doc = Nokogiri::XML(xml_body)
      doc.remove_namespaces!

      entries = doc.xpath("//response").map do |r|
        href     = r.at_xpath("href")&.text.to_s
        name     = r.at_xpath(".//displayname")&.text.presence || File.basename(href)
        is_dir   = r.at_xpath(".//resourcetype/collection") != nil
        size     = r.at_xpath(".//getcontentlength")&.text.to_s
        modified = r.at_xpath(".//getlastmodified")&.text.to_s

        next if href.chomp("/") == base_path.chomp("/")

        {
          name: name,
          path: href,
          type: is_dir ? "directory" : "file",
          size: size,
          modified: modified
        }
      end.compact

      entries.map { |e| "#{e[:type] == 'directory' ? '[DIR]' : '[FILE]'} #{e[:name]} (#{e[:path]})" }.join("\n")
    rescue Nokogiri::XML::SyntaxError => e
      "Error parsing WebDAV response: #{e.message}"
    end
  end
end
