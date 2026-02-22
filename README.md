# Everything Control Plane (ECP)

A single MCP (Model Context Protocol) server that aggregates multiple services, allowing AI assistants (Claude, Gemini, etc.) to connect to one endpoint and access many backends via centrally managed credentials.

## Architecture

```
AI Assistant (Claude / other)
        │  MCP over HTTP (JSON-RPC 2.0)
        ▼
┌──────────────────────────────┐
│  Everything Control Plane    │
│  (Rails API + MCP Server)    │
│                              │
│  ┌─────────────────────────┐ │
│  │   Service Adapters      │ │
│  │  ┌────────┐ ┌────────┐  │ │
│  │  │WebDAV  │ │CalDAV  │  │ │
│  │  └────────┘ └────────┘  │ │
│  │  ┌────────┐ ┌────────┐  │ │
│  │  │Obsidian│ │Gemini  │  │ │
│  │  └────────┘ └────────┘  │ │
│  └─────────────────────────┘ │
│                              │
│  PostgreSQL (credentials,    │
│  sessions, service config)   │
└──────────────────────────────┘
```

## Supported Services

| Adapter   | Protocol      | Description                                              |
|-----------|---------------|----------------------------------------------------------|
| `webdav`  | WebDAV/HTTP   | File operations on any WebDAV server                     |
| `caldav`  | CalDAV/HTTP   | Task management via CalDAV (VTODO)                       |
| `obsidian`| WebDAV/HTTP   | Obsidian vault on Nextcloud (read/write/search notes)    |
| `gemini`  | REST API / CLI| Google Gemini text generation                            |

## Quick Start

### Prerequisites

- Ruby 3.3+
- PostgreSQL 14+
- bundler

### Setup

```bash
# Install dependencies
bundle install

# Set up encryption keys (save these — used for credential encryption)
bundle exec rails runner "
  puts 'PRIMARY_KEY: ' + SecureRandom.hex(32)
  puts 'DET_KEY:     ' + SecureRandom.hex(32)
  puts 'SALT:        ' + SecureRandom.hex(32)
"

# Create .env (see .env.example)
cp .env.example .env
# Edit .env with your values

# Create database and run migrations
bundle exec rails db:create db:migrate

# Seed initial API client (prints one-time token — save it!)
bundle exec rails db:seed

# Start server
bundle exec rails server
```

### Environment Variables

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection URL |
| `SECRET_KEY_BASE` | Rails secret key (run `rails secret`) |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | 32-byte hex key for credential encryption |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | 32-byte hex key |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | 32-byte hex salt |
| `CORS_ORIGINS` | Allowed CORS origins (default: `*`) |

## MCP Transport

ECP implements the MCP **Streamable HTTP** transport (spec 2024-11-05).

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/mcp` | Send JSON-RPC messages (initialize, tools/list, tools/call, etc.) |
| `GET`  | `/mcp/sse` | Server-Sent Events stream |
| `DELETE` | `/mcp/session` | Terminate session |

### Authentication

All requests require a Bearer token:

```
Authorization: Bearer <your-api-token>
```

### Session Flow

```
1. POST /mcp  (no Mcp-Session-Id header)
   → Server creates session, returns Mcp-Session-Id header
   → Send {"jsonrpc":"2.0","id":1,"method":"initialize","params":{...}}

2. POST /mcp  (include Mcp-Session-Id header)
   → {"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
   → {"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"...","arguments":{...}}}
```

## REST API

### Services

```
GET    /api/v1/services
POST   /api/v1/services
GET    /api/v1/services/:id
PATCH  /api/v1/services/:id
DELETE /api/v1/services/:id
POST   /api/v1/services/:id/test_connection
```

### Credentials

```
GET    /api/v1/credentials
POST   /api/v1/credentials
GET    /api/v1/credentials/:id
PATCH  /api/v1/credentials/:id
DELETE /api/v1/credentials/:id
```

### Adding a Service

```bash
# Create a WebDAV service
curl -X POST https://ecp.example.com/api/v1/services \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "service": {
      "name": "nextcloud",
      "adapter_type": "webdav",
      "base_url": "https://nextcloud.example.com/remote.php/dav/files/user/",
      "enabled": true
    }
  }'

# Add credentials for it
curl -X POST https://ecp.example.com/api/v1/credentials \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "credential": {
      "service_id": 1,
      "credential_type": "basic_auth",
      "data": {"username": "user", "password": "pass"}
    }
  }'
```

## Kubernetes Deployment

```bash
# Apply namespace and config
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml

# Edit k8s/secrets.yaml with real values, then apply
kubectl apply -f k8s/secrets.yaml

# Deploy PostgreSQL (or use existing)
kubectl apply -f k8s/postgres.yaml

# Deploy ECP
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Run seed to create initial API client
kubectl exec -n ecp deploy/ecp -- bundle exec rails db:seed
```

## Tool Naming

Each service's tools are prefixed with the service name: `{service_name}__{tool_name}`.

For example, a service named `nextcloud` exposes tools like:
- `nextcloud__list_directory`
- `nextcloud__read_file`
- `nextcloud__write_file`

This prevents collisions when multiple services of the same type are configured.
