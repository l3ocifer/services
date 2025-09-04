#!/bin/bash

# Setup External Access for Route53 Domain
# This script helps configure your homelab for external access with basic auth

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HOMELAB_DIR="/home/l3o/git/homelab"
SERVICES_DIR="$HOMELAB_DIR/services/docker"

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as correct user
check_user() {
    if [[ "$USER" != "l3o" ]]; then
        error "This script must be run as user 'l3o'"
    fi
}

# Get public IP
get_public_ip() {
    log "Getting your public IP address..."
    PUBLIC_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s ipinfo.io/ip 2>/dev/null || echo "UNKNOWN")
    if [[ "$PUBLIC_IP" == "UNKNOWN" ]]; then
        error "Could not determine public IP address. Please check your internet connection."
    fi
    success "Public IP: $PUBLIC_IP"
}

# Create .env file
create_env_file() {
    log "Creating .env file for external access..."
    
    if [[ -f "$SERVICES_DIR/.env" ]]; then
        warning ".env file already exists. Backing up to .env.backup"
        cp "$SERVICES_DIR/.env" "$SERVICES_DIR/.env.backup"
    fi
    
    cat > "$SERVICES_DIR/.env" << EOF
# Environment configuration for external access
# Generated on: $(date)

# Domain configuration
DOMAIN=leopaska.com
DOMAIN_BASE=leopaska

# Local network configuration
LOCAL_DOMAIN=localhost
LOCAL_IP=108.51.59.178

# Database passwords
POSTGRES_PASSWORD=postgresstrongpassword123
REDIS_PASSWORD=redisstrongpassword123

# Authelia specific settings
AUTHELIA_STORAGE_ENCRYPTION_KEY=antidisestablishmentarianism7
AUTHELIA_SESSION_SECRET=antidisestablishmentarianism7
AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET=antidisestablishmentarianism7

# Matrix/Element specific settings
MATRIX_IDENTITY_SERVER_URL=https://vector.im

# Let's Encrypt configuration
ACME_EMAIL=admin@leopaska.com

# Basic Auth credentials (htpasswd format) - Only for admin services
TRAEFIK_AUTH=admin-leopaska:\$\$apr1\$\$YPwrnlVM\$\$w9eKVEBoLqdixVwFYzZzh1
RUSTPAD_AUTH=admin-leopaska:\$\$apr1\$\$8tZvSTfN\$\$6sm0foSfqranEmCXjPiYc1
# Note: OpenWebUI uses its own authentication system (no basic auth needed)

# Additional service passwords
GRAFANA_PASSWORD=admin_password
COOLIFY_PASSWORD=admin_password
VAULTWARDEN_ADMIN_TOKEN=admin_token_here
HUGINN_INVITATION_CODE=demo-access
HUGINN_ADMIN_USERNAME=admin
HUGINN_ADMIN_PASSWORD=admin_password
POSTIZ_JWT_SECRET=jwt_secret_here
POSTIZ_ALLOW_SIGNUP=false
UMAMI_HASH_SALT=random-salt-here
PIHOLE_PASSWORD=admin_password
PGADMIN_EMAIL=admin@leopaska.com
PGADMIN_PASSWORD=admin_password
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
CLICKHOUSE_PASSWORD=clickhouse_password
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=admin_password
MONGO_USERNAME=admin
MONGO_PASSWORD=password

# Resource limits
HOMEASSISTANT_MEMORY_LIMIT=2G
OLLAMA_MEMORY_LIMIT=32G
OLLAMA_MEMORY_RESERVATION=16G
POSTGRES_MEMORY_LIMIT=4G
REDIS_MEMORY_LIMIT=1G
MONITORING_MEMORY_LIMIT=4G
HUGINN_MEMORY_LIMIT=2G

# Data directory
DATA_DIR=/mnt/data
TZ=UTC
EOF
    
    success "Created .env file"
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall for external access..."
    
    # Check if ufw is installed
    if ! command -v ufw &> /dev/null; then
        warning "UFW not installed. Installing..."
        sudo apt update && sudo apt install -y ufw
    fi
    
    # Enable firewall if not already enabled
    if ! sudo ufw status | grep -q "Status: active"; then
        log "Enabling UFW firewall..."
        sudo ufw --force enable
    fi
    
    # Allow HTTP and HTTPS
    sudo ufw allow 80/tcp comment "HTTP"
    sudo ufw allow 443/tcp comment "HTTPS"
    
    # Allow SSH (important!)
    sudo ufw allow 22/tcp comment "SSH"
    
    success "Firewall configured"
    log "Firewall status:"
    sudo ufw status
}

# Deploy services
deploy_services() {
    log "Deploying services..."
    
    cd "$SERVICES_DIR"
    
    # Pull latest images
    log "Pulling latest Docker images..."
    docker-compose pull
    
    # Start services
    log "Starting services..."
    docker-compose up -d
    
    success "Services deployed"
}

# Check service health
check_health() {
    log "Checking service health..."
    
    cd "$SERVICES_DIR"
    
    # Wait a bit for services to start
    sleep 10
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        success "Services are running"
        log "Service status:"
        docker-compose ps
    else
        warning "Some services may not be running properly"
        log "Service status:"
        docker-compose ps
    fi
}

# Display access information
display_access_info() {
    log "External access information:"
    echo
    echo "🌐 Your services will be available at:"
    echo
    echo "Homelab Services:"
    echo "  • Traefik Dashboard: https://leo.traefik.leopaska.com"
    echo "  • Grafana: https://leo.grafana.leopaska.com"
    echo "  • Prometheus: https://leo.metrics.leopaska.com"
    echo "  • Home Assistant: https://leo.home.leopaska.com"
    echo "  • OpenWebUI: https://leo.chat.leopaska.com"
    echo "  • RustPad: https://leo.pad.leopaska.com"
    echo "  • n8n: https://leo.n8n.leopaska.com"
    echo "  • Coolify: https://leo.coolify.leopaska.com"
    echo "  • Matrix: https://leo.matrix.leopaska.com"
    echo "  • Element: https://leo.chat-matrix.leopaska.com"
    echo "  • Vaultwarden: https://leo.vault.leopaska.com"
    echo "  • SpaceDrive: https://leo.drive.leopaska.com"
    echo
    echo "Production Projects:"
    echo "  • DiscoverLocal AI: https://discoverlocal.leopaska.com"
    echo "  • HyvaPaska: https://hyvapaska.com"
    echo "  • Potluck: https://potluck.pub"
    echo "  • TheBlink Live: https://theblink.live"
    echo "  • Omnilemma: https://omnilemma.com"
    echo
    echo "🔐 Basic Auth Credentials:"
    echo "  • Username: demo"
    echo "  • Password: demo"
    echo
    echo "📋 Next Steps:"
    echo "  1. Create Route53 hosted zone for leopaska.com (if not exists)"
    echo "  2. Update your Route53 DNS records:"
    echo "     - A record: leopaska.com → $PUBLIC_IP"
    echo "     - A record: *.leopaska.com → $PUBLIC_IP"
    echo "  3. Wait for DNS propagation (5-10 minutes)"
    echo "  4. Test access to your services"
    echo
    echo "🔧 Troubleshooting:"
    echo "  • Check service logs: docker-compose logs [service-name]"
    echo "  • Check SSL certificates: docker-compose logs traefik | grep -i acme"
    echo "  • Check firewall: sudo ufw status"
}

# Main execution
main() {
    log "Setting up external access for Route53 domain..."
    
    check_user
    get_public_ip
    create_env_file
    configure_firewall
    deploy_services
    check_health
    display_access_info
    
    success "External access setup completed!"
    log "Please update your Route53 DNS records and wait for propagation."
}

# Run main function
main "$@"
