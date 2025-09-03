# Homelab Service

A comprehensive homelab services repository offering both **Ansible-based local deployment** and **Docker containerized deployment** options for managing your entire homelab environment.

This repository consolidates the `devenv` (Ansible) and `llm-docker` (Docker) approaches into a unified services management solution.

## 🏗️ Architecture Overview

This repository consolidates two deployment approaches:

### 1. **Ansible Deployment** (`ansible/`)
- **Purpose**: Local server installation and Raspberry Pi cluster management
- **Target**: 30-node Raspberry Pi cluster + high-resource desktop server
- **Services**: Native installations with systemd, direct hardware access
- **Best for**: Production environments, hardware-specific configurations, resource optimization

### 2. **Docker Deployment** (`docker/`)
- **Purpose**: Containerized services for rapid deployment and isolation
- **Target**: Single high-resource server (55GB RAM, 6TB storage)
- **Services**: Containerized applications with Docker Compose
- **Best for**: Development, testing, quick setup, service isolation

## 🚀 Quick Start

### Option 1: Ansible Deployment (Local Services)
```bash
cd ansible/
ansible-galaxy install -r requirements.yml
ansible-playbook site.yml
```

### Option 2: Docker Deployment (Containerized)
```bash
cd docker/
cp .env.example .env
# Edit .env with your configuration
docker-compose up -d
```

## 📁 Repository Structure

```
services/
├── README.md                 # This file
├── ansible/                  # Ansible-based deployment (from devenv)
│   ├── site.yml             # Main playbook
│   ├── inventory/           # Host inventory
│   ├── group_vars/          # Group variables
│   ├── roles/               # Ansible roles
│   └── playbooks/           # Additional playbooks
├── docker/                  # Docker-based deployment (from llm-docker)
│   ├── docker-compose.yml   # Main compose file
│   ├── .env.example         # Environment template
│   ├── traefik/             # Reverse proxy config
│   ├── authelia/            # Authentication config
│   └── [service-configs]/   # Service configurations
├── docs/                    # Documentation
│   ├── ansible-deployment.md
│   ├── docker-deployment.md
│   └── service-comparison.md
└── scripts/                 # Utility scripts
    ├── migrate-to-docker.sh
    ├── migrate-to-ansible.sh
    └── health-check.sh
```

## 🎯 Service Coverage

Both deployment methods provide the same core services:

### Core Infrastructure
- **Traefik**: Reverse proxy with SSL/TLS
- **PostgreSQL**: Database services
- **Redis**: Caching layer
- **Vector**: Log aggregation

### AI & Development
- **Ollama**: Local LLM serving
- **OpenWebUI**: AI chat interface
- **LibreChat**: Alternative AI interface
- **Rustpad**: Collaborative editor

### Monitoring & Observability
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Loki**: Log aggregation
- **Uptime Kuma**: Service monitoring

### Security & Authentication
- **Authelia**: SSO and 2FA
- **Vaultwarden**: Password management
- **UFW/Fail2ban**: Network security

### Communication & Collaboration
- **Matrix/Conduit**: Secure messaging
- **Jitsi**: Video conferencing
- **RustDesk**: Remote desktop
- **Syncthing**: File synchronization

### Automation & Productivity
- **n8n**: Workflow automation
- **Huginn**: Event processing
- **Coolify**: Container management
- **Home Assistant**: Home automation

## 🔄 Migration Between Deployment Types

The repository includes scripts to migrate between deployment methods:

```bash
# Migrate from Ansible to Docker
./scripts/migrate-to-docker.sh

# Migrate from Docker to Ansible
./scripts/migrate-to-ansible.sh
```

## 📊 Resource Requirements

### Ansible Deployment
- **Desktop Server**: 55GB RAM, 6TB storage
- **Raspberry Pi Cluster**: 30 nodes (1GB RAM each)
- **Network**: Gigabit ethernet recommended

### Docker Deployment
- **Single Server**: 55GB RAM, 6TB storage
- **CPU**: 8+ cores recommended
- **Network**: Gigabit ethernet

## 🔧 Configuration

### Environment Variables
Both deployment methods use similar environment variables:
- `DOMAIN`: Your domain name
- `LOCAL_DOMAIN`: Local domain for development
- `DATA_DIR`: Data storage directory
- `POSTGRES_PASSWORD`: Database password
- `REDIS_PASSWORD`: Redis password

### AWS Integration
- Route53 DNS management
- S3-compatible storage (MinIO)
- Multi-account support

## 📚 Documentation

- [Ansible Deployment Guide](docs/ansible-deployment.md)
- [Docker Deployment Guide](docs/docker-deployment.md)
- [Service Comparison](docs/service-comparison.md)
- [Migration Guide](docs/migration-guide.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test both deployment methods
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 👥 Support

- Create an issue for bugs or feature requests
- Check the documentation for common questions
- Review the service comparison guide for deployment decisions
