source "https://rubygems.org"

gem "rails", "~> 8.1.2"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Authentication
gem "bcrypt", "~> 3.1.7"
gem "jwt", "~> 2.8"

# Rails 8 built-in Active Record Encryption is used for credentials (no extra gems needed)

# HTTP client for proxying requests
gem "faraday", "~> 2.9"
gem "faraday-multipart"

# WebDAV / CalDAV (implemented via Faraday HTTP - WebDAV is HTTP with extra verbs)
gem "nokogiri", "~> 1.16"  # XML parsing for WebDAV/CalDAV responses

# JSON handling
gem "oj", "~> 3.16"

# CORS
gem "rack-cors"

# Background jobs
gem "solid_queue"
gem "solid_cache"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "bundler-audit", require: false
end

group :development do
  gem "listen", "~> 3.3"
end
