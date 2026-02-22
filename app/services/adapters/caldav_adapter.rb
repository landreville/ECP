module Adapters
  # CalDAV adapter — exposes calendar/task operations over MCP.
  # CalDAV is built on top of WebDAV; tasks are stored as VTODO iCalendar objects.
  class CaldavAdapter < BaseAdapter
    def tools
      [
        build_tool(
          name: "list_calendars",
          description: "List available calendars/task lists on the CalDAV server",
          input_schema: {
            type: "object",
            properties: {}
          }
        ) { |_args| list_calendars },

        build_tool(
          name: "list_tasks",
          description: "List tasks (VTODO) from a CalDAV calendar",
          input_schema: {
            type: "object",
            properties: {
              calendar_path: { type: "string", description: "Path to the calendar collection" },
              status:        { type: "string", description: "Filter by status: NEEDS-ACTION, IN-PROCESS, COMPLETED, CANCELLED" }
            },
            required: ["calendar_path"]
          }
        ) { |args| list_tasks(args["calendar_path"], args["status"]) },

        build_tool(
          name: "create_task",
          description: "Create a new task (VTODO) in a CalDAV calendar",
          input_schema: {
            type: "object",
            properties: {
              calendar_path: { type: "string", description: "Path to the calendar collection" },
              summary:       { type: "string", description: "Task title/summary" },
              description:   { type: "string", description: "Task description" },
              due:           { type: "string", description: "Due date in ISO 8601 format (YYYY-MM-DD)" },
              priority:      { type: "integer", description: "Priority 1 (highest) to 9 (lowest)" }
            },
            required: ["calendar_path", "summary"]
          }
        ) { |args| create_task(args) },

        build_tool(
          name: "update_task_status",
          description: "Update the status of an existing task",
          input_schema: {
            type: "object",
            properties: {
              task_url: { type: "string", description: "Full URL or path to the task .ics file" },
              status:   { type: "string", description: "New status: NEEDS-ACTION, IN-PROCESS, COMPLETED, CANCELLED" }
            },
            required: ["task_url", "status"]
          }
        ) { |args| update_task_status(args["task_url"], args["status"]) },

        build_tool(
          name: "delete_task",
          description: "Delete a task from a CalDAV calendar",
          input_schema: {
            type: "object",
            properties: {
              task_url: { type: "string", description: "Full URL or path to the task .ics file" }
            },
            required: ["task_url"]
          }
        ) { |args| delete_task(args["task_url"]) }
      ]
    end

    def test_connection
      conn = http_connection
      # CalDAV discovery via OPTIONS request
      response = conn.run_request(:options, "/", nil, {})
      dav_header = response.headers["dav"] || response.headers["DAV"] || ""
      if dav_header.include?("calendar-access")
        { success: true, message: "CalDAV connection successful (calendar-access supported)" }
      else
        { success: true, message: "Connection successful (DAV: #{dav_header})" }
      end
    rescue => e
      { success: false, message: e.message }
    end

    private

    REPORT_VTODO = <<~XML.freeze
      <?xml version="1.0" encoding="utf-8"?>
      <C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        <D:prop>
          <D:getetag/>
          <C:calendar-data/>
        </D:prop>
        <C:filter>
          <C:comp-filter name="VCALENDAR">
            <C:comp-filter name="VTODO"/>
          </C:comp-filter>
        </C:filter>
      </C:calendar-query>
    XML

    def list_calendars
      conn = http_connection
      body = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
          <D:prop>
            <D:displayname/>
            <D:resourcetype/>
            <C:supported-calendar-component-set/>
          </D:prop>
        </D:propfind>
      XML

      principal_path = config["principal_path"] || "/principals/users/"
      response = conn.run_request(:propfind, principal_path, body,
                                  "Depth" => "1", "Content-Type" => "application/xml")

      doc = Nokogiri::XML(response.body)
      doc.remove_namespaces!

      calendars = doc.xpath("//response").filter_map do |r|
        name = r.at_xpath(".//displayname")&.text
        href = r.at_xpath("href")&.text
        comp_set = r.xpath(".//comp/@name").map(&:value)
        next if name.blank? || comp_set.empty?

        "#{name} (#{href}) - supports: #{comp_set.join(', ')}"
      end

      calendars.join("\n")
    rescue => e
      "Error listing calendars: #{e.message}"
    end

    def list_tasks(calendar_path, status_filter = nil)
      conn = http_connection
      response = conn.run_request(
        :report,
        calendar_path,
        REPORT_VTODO,
        "Depth" => "1", "Content-Type" => "application/xml"
      )

      doc = Nokogiri::XML(response.body)
      doc.remove_namespaces!

      tasks = []
      doc.xpath("//calendar-data").each do |data|
        task = parse_vtodo(data.text)
        next if task.nil?
        next if status_filter.present? && task[:status] != status_filter.upcase

        tasks << format_task(task)
      end

      tasks.empty? ? "No tasks found" : tasks.join("\n---\n")
    rescue => e
      "Error listing tasks: #{e.message}"
    end

    def create_task(args)
      uid  = SecureRandom.uuid
      now  = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      ical = build_vtodo_ical(uid: uid, now: now, **args.symbolize_keys)

      conn      = http_connection
      task_path = "#{args['calendar_path'].chomp('/')}/#{uid}.ics"

      conn.put(task_path) do |req|
        req.body = ical
        req.headers["Content-Type"] = "text/calendar; charset=utf-8"
      end

      "Task created: #{uid}"
    rescue => e
      "Error creating task: #{e.message}"
    end

    def update_task_status(task_url, new_status)
      conn     = http_connection
      response = conn.get(task_url)
      ical     = response.body

      # Replace STATUS line (or insert one)
      if ical.match?(/^STATUS:/m)
        ical = ical.gsub(/^STATUS:.*$/m, "STATUS:#{new_status.upcase}")
      else
        ical = ical.gsub(/^END:VTODO/m, "STATUS:#{new_status.upcase}\r\nEND:VTODO")
      end

      if new_status.upcase == "COMPLETED"
        completed_at = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
        ical = ical.gsub(/^END:VTODO/m, "COMPLETED:#{completed_at}\r\nEND:VTODO")
      end

      conn.put(task_url) do |req|
        req.body = ical
        req.headers["Content-Type"] = "text/calendar; charset=utf-8"
      end

      "Task status updated to #{new_status}"
    rescue => e
      "Error updating task: #{e.message}"
    end

    def delete_task(task_url)
      conn = http_connection
      conn.delete(task_url)
      "Task deleted: #{task_url}"
    rescue => e
      "Error deleting task: #{e.message}"
    end

    def parse_vtodo(ical_text)
      return nil unless ical_text.include?("BEGIN:VTODO")

      extract = ->(field) {
        ical_text.match(/^#{field}[;:]([^\r\n]+)/m)&.[](1)&.strip
      }

      {
        uid:         extract.("UID"),
        summary:     extract.("SUMMARY"),
        description: extract.("DESCRIPTION"),
        status:      extract.("STATUS") || "NEEDS-ACTION",
        due:         extract.("DUE") || extract.("DTSTART"),
        priority:    extract.("PRIORITY")
      }
    end

    def format_task(task)
      lines = ["TASK: #{task[:summary]}"]
      lines << "  Status: #{task[:status]}"
      lines << "  Due: #{task[:due]}"    if task[:due].present?
      lines << "  Priority: #{task[:priority]}" if task[:priority].present?
      lines << "  Description: #{task[:description]}" if task[:description].present?
      lines << "  UID: #{task[:uid]}"
      lines.join("\n")
    end

    def build_vtodo_ical(uid:, now:, calendar_path: nil, summary:, description: nil, due: nil, priority: nil, **)
      lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//ECP//Everything Control Plane//EN",
        "BEGIN:VTODO",
        "UID:#{uid}",
        "DTSTAMP:#{now}",
        "CREATED:#{now}",
        "LAST-MODIFIED:#{now}",
        "SUMMARY:#{summary}",
        "STATUS:NEEDS-ACTION"
      ]

      lines << "DESCRIPTION:#{description}" if description.present?
      lines << "DUE;VALUE=DATE:#{due.gsub('-', '')}" if due.present?
      lines << "PRIORITY:#{priority}" if priority.present?

      lines += ["END:VTODO", "END:VCALENDAR"]
      lines.join("\r\n") + "\r\n"
    end
  end
end
