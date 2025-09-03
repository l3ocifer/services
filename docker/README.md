# LLM Docker Infrastructure

A comprehensive self-hosted AI infrastructure with 20+ services optimized for Ubuntu desktop server with 55GB RAM and 6TB external drive.

## Deployment Management with Coolify

This infrastructure integrates with Coolify for deployment management, allowing you to:

- Manage both the LLM infrastructure and Raspberry Pi cluster (30 nodes) from a single dashboard
- Monitor service health and resource usage across all devices
- Automate deployments and updates to both the main server and Pi cluster
- Scale services across your homelab as needed

Coolify handles:
- Deployment orchestration
- Load balancing
- Health monitoring
- Automated backups
- Scaling and resource allocation

For more information on using Coolify with this infrastructure, see the [Coolify Integration](#coolify-integration) section in the deployment checklist.

## Raspberry Pi Cluster Management

This infrastructure integrates with your existing Coolify installation to manage a cluster of 30 Raspberry Pi devices. Key features include:

### Cluster Architecture
- **Central Management Node**: The Ubuntu desktop server (55GB RAM, 6TB storage)
- **Edge Nodes**: 30 Raspberry Pi devices for distributed computing
- **Management Layer**: Coolify for orchestration and deployment

### Deployment Strategy
- **Core Services**: Run on the main Ubuntu server (LLMs, databases, storage)
- **Edge Services**: Deploy to Raspberry Pi nodes based on architecture compatibility
- **Load Distribution**: Automatically balance workloads across the cluster

### Compatible Pi Services
The following services are suitable for deployment on Raspberry Pi nodes:
- **Vector**: For distributed log collection
- **Prometheus Node Exporters**: For cluster-wide monitoring
- **Syncthing Nodes**: For distributed file synchronization
- **Matrix Federation**: For distributed communication

### Scaling Strategy
1. **Vertical Scaling**: Optimize resource allocation on the main server
2. **Horizontal Scaling**: Distribute workloads to Raspberry Pi nodes
3. **Dynamic Scaling**: Use Coolify to adjust resources based on demand

For detailed configuration of the Raspberry Pi cluster, see the [Coolify Integration](#coolify-integration) section.

## Services

### Core Infrastructure
- **Traefik**: Reverse proxy with SSL/TLS support and authentication
- **Ollama**: Local LLM service for running AI models
- **Open WebUI**: Web interface for interacting with Ollama
- **Neon**: PostgreSQL database for structured data storage
- **Redis**: In-memory data store for caching
- **Vector**: Log and metrics collection pipeline

### Monitoring & Observability
- **Prometheus**: Metrics collection and storage
- **Grafana**: Metrics visualization and dashboards
- **Loki**: Log aggregation and querying
- **Uptime Kuma**: Service monitoring and uptime tracking
- **Node-exporter**: System metrics exporter

### Security & Authentication
- **Authelia**: SSO and 2FA authentication provider
- **Vaultwarden**: Password manager (Bitwarden compatible)

### Storage & File Management
- **MinIO**: S3-compatible object storage
- **Spacedrive**: File manager with web interface

### Collaboration & Productivity
- **Rustpad**: Collaborative text editor
- **Matrix/Conduit**: Secure messaging and communication
- **n8n**: Workflow automation
- **Syncthing**: File synchronization
- **Postiz**: Notes and knowledge management
- **RustDesk**: Remote desktop access

## Prerequisites
- Ubuntu 22.04 LTS or later
- Docker and Docker Compose
- 8+ CPU cores (recommended)
- 32GB+ RAM (55GB optimal)
- External storage device mounted at `/mnt/data` (6TB recommended)
- Domain name (for remote access)
- (Optional) NVIDIA GPU with CUDA support

## Quick Start
```bash
# Clone the repository
git clone https://github.com/yourusername/llm-docker.git
cd llm-docker

# Copy and edit the environment file
cp .env.example .env
nano .env  # Edit with your domain and secrets

# Run the setup script
chmod +x setup.sh
./setup.sh

# Wait for setup to complete (~5-10 minutes)
```

## Accessing Your Services

### Local Access
```
• OpenWebUI:     http://chat.localhost
• Ollama API:    http://api.localhost
• Traefik:       http://traefik.localhost
• Rustpad:       http://pad.localhost
• Prometheus:    http://metrics.localhost
• Grafana:       http://grafana.localhost
• Loki:          http://logs.localhost
• Authelia:      http://auth.localhost
• n8n:           http://n8n.localhost
• Uptime Kuma:   http://status.localhost
• Vaultwarden:   http://vault.localhost
• Matrix:        http://matrix.localhost
• RustDesk:      http://remote.localhost
• Syncthing:     http://sync.localhost
• Postiz:        http://notes.localhost
• MinIO API:     http://s3.localhost
• MinIO Console: http://s3-console.localhost
• Spacedrive:    http://files.localhost
```

### Remote Access
With a configured domain and DNS records:
```
• OpenWebUI:     https://chat.yourdomain.com
• Ollama API:    https://api.yourdomain.com
• Traefik:       https://traefik.yourdomain.com
• Rustpad:       https://pad.yourdomain.com
• Prometheus:    https://metrics.yourdomain.com
• Grafana:       https://grafana.yourdomain.com
• Loki:          https://logs.yourdomain.com
• Authelia:      https://auth.yourdomain.com
• n8n:           https://n8n.yourdomain.com
• Uptime Kuma:   https://status.yourdomain.com
• Vaultwarden:   https://vault.yourdomain.com
• Matrix:        https://matrix.yourdomain.com
• RustDesk:      https://remote.yourdomain.com
• Syncthing:     https://sync.yourdomain.com
• Postiz:        https://notes.yourdomain.com
• MinIO API:     https://s3.yourdomain.com
• MinIO Console: https://s3-console.yourdomain.com
• Spacedrive:    https://files.yourdomain.com
```

## Resource Usage
- **RAM**: ~20-35GB for all services at normal load
- **CPU**: 4-8 cores depending on LLM inference load
- **Storage**: ~200GB for base installation, expandable based on usage
- **Headroom**: ~20GB RAM available for additional services or larger models

## Security Features
- SSL/TLS encryption via Let's Encrypt
- Authentication for all services
- IP whitelisting for local access
- Security headers (XSS protection, HSTS, etc.)
- Strict password policies

## Management Scripts
- `setup.sh`: Initial setup and configuration
- `rebuild.sh`: Update and restart services
- `teardown.sh`: Stop and clean up resources

## Configuration
- Environment variables in `.env`
- Traefik configuration in `traefik/config/`
- Service configuration in `docker-compose.yml`

## Troubleshooting
1. Check service status: `docker-compose ps`
2. View logs: `docker-compose logs [service]`
3. Verify network connectivity: `docker network inspect llm_network`
4. Check Traefik dashboard for routing issues

## Performance Tips
- Use smaller models for faster inference (llama3.2:3b is recommended for everyday use)
- For larger models, adjust memory limits in `.env`
- Enable GPU support by uncommenting GPU-related lines in `docker-compose.yml`
- Run `./rebuild.sh --clean` to refresh all services and volumes

## Coolify Integration

### Importing Existing Setup

To integrate your existing Coolify installation with this infrastructure:

1. Ensure network connectivity between Coolify and the LLM services:
   ```bash
   # Add the LLM network to your existing Coolify installation
   docker network connect llm_network coolify-container-name
   ```

2. In Coolify, add the LLM services as managed resources:
   - Use the service network names as hostnames (e.g., `ollama`, `webui`)
   - Configure health checks using the same parameters defined in `docker-compose.yml`
   
3. For Raspberry Pi cluster management:
   - Ensure all Pi nodes are in the same network or can reach the main server
   - Configure Coolify to deploy specific services to the Pi cluster based on architecture compatibility

### Managing the Infrastructure

- Use Coolify to monitor resource usage and automatically scale services
- Set up deployment pipelines for continuous updates
- Configure automatic backups of critical data

# Matrix and Authelia Local Testing

To test the Matrix and Authelia setup with local access:

1. Generate a `.env` file with the included script:
   ```bash
   ./generate-env.sh [your-domain]
   ```
   If you don't specify a domain, it will use the default `codeofconsciousness.com`.

2. Start only the required services:
   ```bash
   docker-compose up -d traefik neon-postgres redis-nd authelia element conduit
   ```

3. Access the services using the following URLs:
   - **Authelia**: http://auth.localhost
   - **Element (Matrix client)**: http://chat-matrix.localhost
   - **Conduit (Matrix server)**: http://matrix.localhost

   You can also access them using IP addresses directly.

4. Check logs if you encounter any issues:
   ```bash
   docker-compose logs -f authelia
   docker-compose logs -f element 
   docker-compose logs -f conduit
   ```

## Troubleshooting Local Access

If you have issues with local access:

1. Ensure the `LOCAL_DOMAIN` and `LOCAL_IP` in `.env` are set correctly
2. Add entries to your hosts file for local testing:
   ```
   127.0.0.1 auth.localhost chat-matrix.localhost matrix.localhost
   ```
3. Check that the traefik local-only middleware is correctly configured
