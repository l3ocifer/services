# MCP Modules Rust Server

A comprehensive Model Context Protocol (MCP) server providing 36+ tools for homelab management, development, and automation.

## Overview

The MCP Modules Rust server provides unified access to all your homelab services through a standardized interface. It includes tools for:

- **Infrastructure Management**: Docker, Kubernetes, Traefik
- **Monitoring & Observability**: Prometheus, Grafana, Uptime Kuma, Vector logs
- **Security & Authentication**: Authelia, Vaultwarden
- **Deployment & Automation**: Coolify, N8N workflows
- **Databases**: PostgreSQL, MongoDB, Supabase
- **Office Automation**: PowerPoint, Word, Excel creation
- **Smart Home**: Home Assistant integration
- **Finance**: Alpaca trading API
- **Research & Maps**: Deep research, OpenStreetMap
- **Memory & AI**: Knowledge graph, LLM response storage

## Service Configuration

### Docker Compose
```yaml
mcp-modules-rust:
  build:
    context: https://github.com/l3ocifer/mcp-modules-rust.git
    dockerfile: Dockerfile
  container_name: mcp-modules-rust-${DOMAIN_BASE}
  restart: unless-stopped
  ports:
    - "8890:8890"
  environment:
    - MCP_HTTP_HOST=0.0.0.0
    - MCP_HTTP_PORT=8890
    - RUST_LOG=devops_mcp=info,tower_http=debug
  networks:
    - llm_network
```

### Traefik Labels
- **Internal Access**: `mcp.localhost`, `mcp.lan`, or LAN IP
- **External Access**: `mcp.${DOMAIN}` (if configured)
- **Port**: 8890
- **Health Check**: `/health` endpoint

## API Endpoints

### Health Check
```bash
curl http://localhost:8890/health
```

### List Available Tools
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' \
  http://localhost:8890
```

### Execute Tool
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"health_check"}}' \
  http://localhost:8890
```

## Integration with Cursor IDE

The server includes stdio bridges for both local and remote integration with Cursor IDE:

### Local Access (Same Machine)
1. **Configuration**: `~/.cursor/mcp.json`
```json
{
  "mcpServers": {
    "devops-mcp-rust": {
      "command": "node",
      "args": ["/home/l3o/git/l3ocifer/mcp-modules-rust/scripts/mcp-stdio-bridge.js"],
      "env": {
        "MCP_SERVER_URL": "http://localhost:8890"
      }
    }
  }
}
```

### Remote Access (Other Laptops/Devices)
1. **Clone Repository**: 
```bash
git clone https://github.com/l3ocifer/mcp-modules-rust.git
cd mcp-modules-rust
```

2. **Configuration**: `~/.cursor/mcp.json`
```json
{
  "mcpServers": {
    "devops-mcp-rust": {
      "command": "node",
      "args": ["/path/to/mcp-modules-rust/scripts/mcp-stdio-bridge-remote.js"],
      "env": {
        "MCP_SERVER_URL": "https://mcp.leopaska.xyz"
      }
    }
  }
}
```

3. **Bridge Scripts**: 
   - **Local**: `mcp-stdio-bridge.js` - Connects to localhost:8890
   - **Remote**: `mcp-stdio-bridge-remote.js` - Connects to https://mcp.leopaska.xyz

### Cloudflare Tunnel Integration
The MCP server is exposed via your existing Cloudflare tunnel at:
- **URL**: `https://mcp.leopaska.xyz`
- **Authentication**: Protected by Authelia (same as other services)
- **SSL**: Automatic via Cloudflare
- **Access**: Available from anywhere with proper authentication

## Available Tools (36 total)

### Homelab Infrastructure (11 tools)
- `traefik_list_services` - List Traefik services and routes
- `traefik_service_health` - Check Traefik service health
- `prometheus_query` - Query Prometheus metrics with PromQL
- `grafana_dashboards` - List and manage Grafana dashboards
- `coolify_deployments` - Manage Coolify application deployments
- `n8n_workflows` - List and manage N8N workflows
- `uptime_monitors` - Check Uptime Kuma monitor status
- `authelia_users` - Manage Authelia authentication and users
- `vaultwarden_status` - Check Vaultwarden server and backup status
- `vector_logs` - Query Vector log pipeline status and metrics
- `service_health_check` - General health checks for homelab services

### Core Infrastructure (4 tools)
- `list_docker_containers` - List Docker containers
- `get_container_logs` - Get Docker container logs
- `list_k8s_pods` - List Kubernetes pods
- `get_pod_logs` - Get Kubernetes pod logs

### Database Management (3 tools)
- `list_databases` - List available databases
- `execute_query` - Execute database queries
- `list_tables` - List database tables

### Office Automation (3 tools)
- `create_presentation` - Create PowerPoint presentations
- `create_document` - Create Word documents
- `create_workbook` - Create Excel workbooks

### Memory & AI (3 tools)
- `create_memory` - Store knowledge in memory graph
- `search_memory` - Search stored memories
- `store_llm_response` - Store LLM responses

### Smart Home (3 tools)
- `ha_turn_on` - Turn on Home Assistant devices
- `ha_turn_off` - Turn off Home Assistant devices
- `ha_set_temperature` - Set climate control temperature

### Finance (3 tools)
- `get_account_info` - Get Alpaca trading account info
- `get_stock_quote` - Get real-time stock quotes
- `place_order` - Place stock trading orders

### Research & Maps (3 tools)
- `deep_research` - Conduct deep research on topics
- `query_overpass` - Query OpenStreetMap data
- `find_places` - Find places near locations

### Government & Security (3 tools)
- `search_grants` - Search government grants
- `health_check` - System health status
- `security_validate` - Validate input for security

## Deployment

### Building the Container
```bash
cd /home/l3o/git/homelab/services
docker-compose build mcp-modules-rust
```

### Starting the Service
```bash
docker-compose up -d mcp-modules-rust
```

### Viewing Logs
```bash
docker-compose logs -f mcp-modules-rust
```

### Health Check
```bash
docker-compose exec mcp-modules-rust curl -f http://localhost:8890/health
```

## Monitoring

- **Health Check**: Automatic Docker health checks every 30s
- **Logs**: Structured JSON logging with configurable levels
- **Metrics**: Prometheus metrics available (if enabled)
- **Traefik Integration**: Automatic service discovery and routing

## Development

### Local Development
```bash
cd /home/l3o/git/l3ocifer/mcp-modules-rust
cargo run --release
```

### Environment Variables
- `MCP_HTTP_HOST`: Bind host (default: 0.0.0.0)
- `MCP_HTTP_PORT`: Bind port (default: 8890)
- `RUST_LOG`: Logging level (default: info)

## Architecture

- **Language**: Rust with Tokio async runtime
- **Protocol**: JSON-RPC over HTTP
- **Transport**: HTTP server with stdio bridge for IDE integration
- **Modules**: Modular architecture with separate modules for each domain
- **Performance**: Zero-copy operations, efficient memory management
- **Security**: Input validation, rate limiting via Traefik

## Dependencies

- **Runtime**: Debian bookworm-slim
- **Build**: Rust 1.75+ with cargo
- **Network**: Traefik for routing and SSL
- **Monitoring**: Optional Prometheus integration
