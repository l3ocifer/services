# Ollama Proxy Fortress - Unified API Security Gateway

Integration of [Ollama Proxy Fortress](https://github.com/ParisNeo/ollama_proxy_server) into the homelab for centralized API key management and security.

## Overview

The Ollama Proxy Fortress provides:
- **🔑 API Key Authentication** for all API services
- **👥 Multi-User Management** with per-user rate limits
- **🛡️ Security Gateway** protecting Ollama and MCP services
- **📊 Usage Analytics** and monitoring
- **🌐 Unified Access** for all laptops/devices

## Service Configuration

### Docker Compose Service
```yaml
ollama-proxy:
  build:
    context: https://github.com/ParisNeo/ollama_proxy_server.git
    dockerfile: Dockerfile
  container_name: ollama-proxy-leopaska
  restart: unless-stopped
  ports:
    - "8888:8080"
  environment:
    # Core proxy settings
    - HOST=0.0.0.0
    - PORT=8080
    - SECRET_KEY=ollama-proxy-secret-key-change-me
    - ADMIN_PASSWORD=secure-admin-password
    # Database configuration
    - DATABASE_URL=sqlite:////data/ollama_proxy.db
    # Backend servers (MCP Server)
    - OLLAMA_SERVERS=http://mcp-modules-rust:8890
    # Rate limiting
    - GLOBAL_RATE_LIMIT=100
    - BURST_RATE_LIMIT=200
    # Security settings
    - ENABLE_ANALYTICS=true
    - LOG_LEVEL=INFO
```

### Traefik Integration
- **Admin Interface**: `proxy-admin.leopaska.xyz` (basic auth protected)
- **API Gateway**: `proxy-api.leopaska.xyz` (API key protected)

### Cloudflare Tunnel Routes
- `proxy-admin.leopaska.xyz` → Admin interface for managing API keys
- `proxy-api.leopaska.xyz` → Secured API gateway for all services

## Architecture

```
Remote Laptops → Cloudflare Tunnel → Traefik → Ollama Proxy Fortress → MCP Server
                                                     ↓
                                              API Key Validation
                                              Rate Limiting
                                              Usage Analytics
```

## Security Features

### 1. API Key Authentication
- **Per-User Keys**: Individual API keys for each user/device
- **Rate Limiting**: Configurable per-key and global limits
- **Key Management**: Enable/disable keys without deletion
- **Usage Tracking**: Monitor API usage per key

### 2. Multi-Layer Security
- **Cloudflare**: DDoS protection, WAF
- **Traefik**: SSL termination, routing
- **Basic Auth**: Admin interface protection
- **API Keys**: Service access control
- **Rate Limiting**: Abuse prevention

### 3. Access Control
- **Admin Interface**: `proxy-admin.leopaska.xyz` (username/password)
- **API Access**: `proxy-api.leopaska.xyz` (API keys)
- **Direct Service Access**: Blocked (services only accessible via proxy)

## Setup Process

### 1. Deploy the Service
```bash
cd /home/l3o/git/homelab/services
docker-compose build ollama-proxy
docker-compose up -d ollama-proxy
```

### 2. Configure DNS Records
```bash
export CLOUDFLARE_API_TOKEN="your-token"
cloudflared tunnel route dns 8a8129e7-f8c3-4cc4-8b1f-9995da97fff0 proxy-admin.leopaska.xyz
cloudflared tunnel route dns 8a8129e7-f8c3-4cc4-8b1f-9995da97fff0 proxy-api.leopaska.xyz
```

### 3. Update Cloudflare Tunnel
```bash
cd /home/l3o/git/homelab/services/cloudflare-tunnel
./generate-config.sh
# Restart cloudflared to apply new config
```

### 4. Access Admin Interface
- **URL**: `https://proxy-admin.leopaska.xyz`
- **Login**: `lpask001` / `secure-admin-password`
- **Function**: Create and manage API keys

## API Key Usage

### For MCP Tools (Cursor IDE)
Update `~/.cursor/mcp.json`:
```json
{
  "mcpServers": {
    "devops-mcp-rust-secure": {
      "command": "node",
      "args": ["/path/to/mcp-modules-rust/scripts/mcp-stdio-bridge-proxy.js"],
      "env": {
        "MCP_SERVER_URL": "https://proxy-api.leopaska.xyz",
        "API_KEY": "your-generated-api-key"
      }
    }
  }
}
```

### For Ollama Access
```bash
curl https://proxy-api.leopaska.xyz/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{"model": "llama3", "prompt": "Hello"}'
```

## Benefits

### 🔒 **Enhanced Security**
- No direct access to MCP or Ollama servers
- API key authentication required
- Rate limiting prevents abuse
- Centralized access control

### 📊 **Monitoring & Analytics**
- Track API usage per user/device
- Monitor rate limit violations
- Usage statistics and reporting
- Real-time dashboard

### 🌐 **Unified Access**
- Single API gateway for all services
- Consistent authentication across devices
- Centralized user management
- Easy key rotation and management

### 🚀 **Scalability**
- Add new backend services easily
- Load balancing across multiple instances
- Per-service rate limiting
- Horizontal scaling support

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOST` | Bind host | `0.0.0.0` |
| `PORT` | Bind port | `8080` |
| `SECRET_KEY` | JWT secret key | Required |
| `ADMIN_PASSWORD` | Admin login password | Required |
| `DATABASE_URL` | SQLite database path | `sqlite:////data/ollama_proxy.db` |
| `OLLAMA_SERVERS` | Backend server URLs | Required |
| `GLOBAL_RATE_LIMIT` | Global rate limit | `100` |
| `BURST_RATE_LIMIT` | Burst rate limit | `200` |
| `ENABLE_ANALYTICS` | Enable usage analytics | `true` |
| `LOG_LEVEL` | Logging level | `INFO` |

## Next Steps

1. **Deploy the proxy service**
2. **Create DNS records** for proxy subdomains  
3. **Access admin interface** to create API keys
4. **Update MCP bridge** to use API key authentication
5. **Test unified access** from remote devices

This setup provides **enterprise-grade security** for your homelab API services while maintaining ease of use and centralized management.
