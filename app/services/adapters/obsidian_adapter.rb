module Adapters
  # Obsidian adapter — accesses an Obsidian vault stored in a Nextcloud WebDAV folder.
  # Inherits WebDAV mechanics but adds Obsidian-specific markdown tooling.
  class ObsidianAdapter < BaseAdapter
    # Default vault root within the WebDAV share (configurable via service.config["vault_path"])
    def vault_path
      config["vault_path"] || "/"
    end

    def tools
      [
        build_tool(
          name: "list_notes",
          description: "List Obsidian notes in a directory of the vault",
          input_schema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Path within vault (default: vault root)" }
            }
          }
        ) { |args| list_notes(args["path"] || vault_path) },

        build_tool(
          name: "read_note",
          description: "Read an Obsidian note (markdown file)",
          input_schema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Path to the note file (e.g. 'Notes/MyNote.md')" }
            },
            required: ["path"]
          }
        ) { |args| read_note(args["path"]) },

        build_tool(
          name: "write_note",
          description: "Create or overwrite an Obsidian note",
          input_schema: {
            type: "object",
            properties: {
              path:    { type: "string", description: "Note path (e.g. 'Notes/MyNote.md')" },
              content: { type: "string", description: "Markdown content of the note" }
            },
            required: ["path", "content"]
          }
        ) { |args| write_note(args["path"], args["content"]) },

        build_tool(
          name: "append_to_note",
          description: "Append content to an existing Obsidian note",
          input_schema: {
            type: "object",
            properties: {
              path:    { type: "string", description: "Note path" },
              content: { type: "string", description: "Markdown content to append" }
            },
            required: ["path", "content"]
          }
        ) { |args| append_to_note(args["path"], args["content"]) },

        build_tool(
          name: "search_notes",
          description: "Search for notes containing a keyword (simple text search across vault)",
          input_schema: {
            type: "object",
            properties: {
              query: { type: "string", description: "Search term" },
              path:  { type: "string", description: "Directory to search in (optional)" }
            },
            required: ["query"]
          }
        ) { |args| search_notes(args["query"], args["path"] || vault_path) },

        build_tool(
          name: "delete_note",
          description: "Delete an Obsidian note",
          input_schema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Note path to delete" }
            },
            required: ["path"]
          }
        ) { |args| delete_note(args["path"]) }
      ]
    end

    def test_connection
      conn = http_connection
      conn.run_request(:propfind, vault_path, nil, "Depth" => "0")
      { success: true, message: "Obsidian vault accessible at #{vault_path}" }
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
        </D:prop>
      </D:propfind>
    XML

    def full_path(relative_path)
      return vault_path if relative_path.blank?
      "#{vault_path.chomp('/')}/#{relative_path.delete_prefix('/')}"
    end

    def list_notes(path)
      conn = http_connection
      response = conn.run_request(
        :propfind,
        full_path(path),
        PROPFIND_BODY,
        "Depth" => "1", "Content-Type" => "application/xml"
      )

      doc = Nokogiri::XML(response.body)
      doc.remove_namespaces!

      entries = doc.xpath("//response").filter_map do |r|
        href   = r.at_xpath("href")&.text.to_s
        name   = r.at_xpath(".//displayname")&.text.presence || File.basename(href)
        is_dir = r.at_xpath(".//resourcetype/collection") != nil

        next if href.chomp("/") == full_path(path).chomp("/")

        "#{is_dir ? '[DIR]' : '[NOTE]'} #{name}"
      end

      entries.empty? ? "No notes found" : entries.join("\n")
    rescue => e
      "Error listing notes: #{e.message}"
    end

    def read_note(path)
      conn = http_connection
      response = conn.get(full_path(path))
      response.body
    rescue Faraday::ResourceNotFound
      "Note not found: #{path}"
    rescue => e
      "Error reading note: #{e.message}"
    end

    def write_note(path, content)
      conn = http_connection
      conn.put(full_path(path)) do |req|
        req.body = content
        req.headers["Content-Type"] = "text/markdown; charset=utf-8"
      end
      "Note written: #{path}"
    rescue => e
      "Error writing note: #{e.message}"
    end

    def append_to_note(path, content)
      existing = read_note(path)
      # If note doesn't exist yet, create it
      separator = existing.end_with?("\n") ? "" : "\n"
      write_note(path, "#{existing}#{separator}#{content}")
    rescue => e
      "Error appending to note: #{e.message}"
    end

    def search_notes(query, search_path)
      results = find_markdown_files(search_path)
      matches = []

      results.each do |file_path|
        begin
          content = read_note(file_path)
          if content.include?(query)
            # Show matching lines with context
            lines = content.split("\n")
            match_lines = lines.each_with_index.filter_map do |line, idx|
              "  Line #{idx + 1}: #{line.strip}" if line.include?(query)
            end
            matches << "FILE: #{file_path}\n#{match_lines.first(3).join("\n")}"
          end
        rescue
          next
        end
      end

      matches.empty? ? "No notes found containing '#{query}'" : matches.join("\n---\n")
    end

    def delete_note(path)
      conn = http_connection
      conn.delete(full_path(path))
      "Deleted note: #{path}"
    rescue => e
      "Error deleting note: #{e.message}"
    end

    def find_markdown_files(path, acc = [])
      conn = http_connection
      response = conn.run_request(
        :propfind,
        full_path(path),
        PROPFIND_BODY,
        "Depth" => "1", "Content-Type" => "application/xml"
      )

      doc = Nokogiri::XML(response.body)
      doc.remove_namespaces!

      doc.xpath("//response").each do |r|
        href   = r.at_xpath("href")&.text.to_s
        is_dir = r.at_xpath(".//resourcetype/collection") != nil
        next if href.chomp("/") == full_path(path).chomp("/")

        if is_dir
          find_markdown_files(href, acc)
        elsif href.end_with?(".md")
          acc << href
        end
      end

      acc
    rescue => e
      []
    end
  end
end
