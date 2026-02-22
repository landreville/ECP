# Seeds for Everything Control Plane
# Run with: bundle exec rails db:seed

# Create default API client for bootstrapping.
# The generated token is printed once and cannot be recovered — save it immediately.
unless ApiClient.exists?(name: "default")
  client, token = ApiClient.create_with_token(
    name: "default",
    description: "Default API client — created by db:seed",
    allowed_services: []  # empty = allow all services
  )
  puts "=" * 60
  puts "Created default API client"
  puts "  Name:  #{client.name}"
  puts "  Token: #{token}"
  puts ""
  puts "  Save this token — it cannot be retrieved later."
  puts "  Use it as:  Authorization: Bearer #{token}"
  puts "=" * 60
else
  puts "Default API client already exists."
end

# Example services (commented out — configure to match your environment)
#
# Service.find_or_create_by!(name: "nextcloud-webdav") do |s|
#   s.adapter_type = "webdav"
#   s.base_url     = "https://nextcloud.example.com/remote.php/dav/files/username/"
#   s.description  = "Nextcloud WebDAV"
#   s.enabled      = true
# end
#
# Service.find_or_create_by!(name: "tasks") do |s|
#   s.adapter_type = "caldav"
#   s.base_url     = "https://nextcloud.example.com/remote.php/dav/"
#   s.description  = "CalDAV task lists"
#   s.config       = { "principal_path" => "/remote.php/dav/principals/users/username/" }
#   s.enabled      = true
# end
#
# Service.find_or_create_by!(name: "obsidian-vault") do |s|
#   s.adapter_type = "obsidian"
#   s.base_url     = "https://nextcloud.example.com/remote.php/dav/files/username/"
#   s.description  = "Obsidian vault on Nextcloud"
#   s.config       = { "vault_path" => "/Obsidian/" }
#   s.enabled      = true
# end
#
# Service.find_or_create_by!(name: "gemini") do |s|
#   s.adapter_type = "gemini"
#   s.description  = "Google Gemini via API"
#   s.config       = { "default_model" => "gemini-1.5-flash" }
#   s.enabled      = true
# end
