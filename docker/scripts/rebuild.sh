#!/usr/bin/env bash

# This script rebuilds the Docker containers with the latest stable versions
# When run, it will pull the latest images for all services defined in docker-compose.yml
# Services using the 'latest' tag will get the most recent stable version

# Set strict error handling
set -euo pipefail
IFS=$'\n\t'

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function for logging
log() {
    local level=$1
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case "$level" in
        "info")
            echo -e "[${timestamp}] ${BLUE}ℹ${NC} $msg"
            ;;
        "success")
            echo -e "[${timestamp}] ${GREEN}✓${NC} $msg"
            ;;
        "warn")
            echo -e "[${timestamp}] ${YELLOW}!${NC} $msg"
            ;;
        "error")
            echo -e "[${timestamp}] ${RED}✗${NC} $msg"
            ;;
    esac
}

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log "error" "$1 is required but not installed."
        exit 1
    fi
    log "success" "Found required command: $1"
}

# Load environment variables if .env exists
if [ -f .env ]; then
    source .env
fi

# Function to create data directories
create_data_directories() {
    local data_dir="${DATA_DIR:-/mnt/data}"
    
    # Create parent directory if it doesn't exist
    if [ ! -d "$data_dir" ]; then
        log "info" "Creating data directory: $data_dir"
        mkdir -p "$data_dir"
    fi
    
    # List of service directories needed
    local directories=(
        "ollama"
        "webui"
        "postgres"
        "redis"
        "vector"
        "prometheus"
        "grafana"
        "loki"
        "authelia"
        "n8n"
        "uptime-kuma"
        "vaultwarden"
        "matrix"
        "rustdesk"
        "syncthing"
        "postiz"
        "minio"
        "spacedrive"
        "coolify"
        "homeassistant"
        "huginn"
        "whodb"
        "shared"  # For shared files accessible by Spacedrive
    )
    
    # Create each directory
    for dir in "${directories[@]}"; do
        if [ ! -d "$data_dir/$dir" ]; then
            log "info" "Creating service directory: $data_dir/$dir"
            mkdir -p "$data_dir/$dir"
            # Set appropriate permissions
            chmod 755 "$data_dir/$dir"
        fi
    done
    
    log "success" "All data directories created"
}

# Check required commands
check_command docker
check_command docker-compose

# Set DATA_DIR variable if not provided
if [ -z "${DATA_DIR:-}" ]; then
    DATA_DIR="/mnt/data"
    log "info" "DATA_DIR not set, using default: $DATA_DIR"
fi
export DATA_DIR

# Create data directories
create_data_directories

# Stop and remove containers
log "info" "Stopping containers..."
docker-compose down --remove-orphans

# Remove old volumes if --clean flag is provided
if [[ "${1:-}" == "--clean" ]]; then
    log "warn" "Cleaning volumes..."
    docker volume rm $(docker volume ls -q -f name=llm-docker_*) 2>/dev/null || true
    log "warn" "Cleaning networks..."
    docker network rm llm_network 2>/dev/null || true
fi

# Network setup
log "info" "Setting up network..."
if docker network ls | grep -q llm_network; then
    # Check if network has active endpoints
    if docker network inspect llm_network | grep -q "Containers\":{}" || docker network inspect llm_network | grep -q "\"Containers\": {}"; then
        log "info" "Removing existing network..."
        docker network rm llm_network || true
    else
        log "warn" "Network llm_network has active containers"
        log "info" "Checking for containers not managed by this project..."
        
        # Get list of containers connected to the network
        local connected_containers=$(docker network inspect llm_network | grep -A 5 "Containers" | grep "Name" | awk -F'"' '{print $4}' || echo "")
        
        for container in $connected_containers; do
            # Check if container is managed by our project
            local label=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$container" 2>/dev/null || echo "")
            
            if [ "$label" != "llm-docker" ]; then
                log "warn" "Found container not managed by this project: $container"
                log "info" "Disconnecting $container from llm_network..."
                docker network disconnect -f llm_network "$container" || log "warn" "Could not disconnect $container from llm_network"
            fi
        done
    fi
fi

log "info" "Creating network..."
docker network create \
    --label com.docker.compose.project=llm-docker \
    --label com.docker.compose.network=llm_network \
    llm_network || log "warn" "Network may already exist, continuing..."

# Check for container name conflicts
log "info" "Checking for container name conflicts..."

# Get list of services from docker-compose.yml
services=$(docker-compose config --services)

for service in $services; do
    container_name="${service}-${DOMAIN_BASE}"
    
    # Check if container exists but is not managed by our docker-compose project
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        label=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$container_name" 2>/dev/null || echo "")
        
        if [ "$label" != "llm-docker" ]; then
            log "warn" "Found conflicting container: ${container_name}"
            log "info" "Stopping and renaming conflicting container to allow our service to start"
            
            # Stop the container if it's running
            docker stop "$container_name" 2>/dev/null || true
            
            # Rename the container to avoid conflicts
            timestamp=$(date +%s)
            docker rename "$container_name" "${container_name}-old-${timestamp}" 2>/dev/null || true
            
            log "success" "Renamed conflicting container ${container_name} to ${container_name}-old-${timestamp}"
        fi
    fi
done

# Remove existing images to force fresh build
log "info" "Removing existing images..."
docker-compose rm -f

# Pull latest images
log "info" "Pulling latest images (this will get the latest stable versions)..."
docker-compose pull --include-deps

# Build fresh containers
log "info" "Building fresh containers..."
docker-compose build --no-cache

# Function to initialize Coolify
initialize_coolify() {
    log "info" "Initializing Coolify..."
    # Wait for Coolify container to be ready
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker ps | grep -q "coolify-${DOMAIN_BASE}" && [ "$(docker inspect --format='{{.State.Status}}' coolify-${DOMAIN_BASE} 2>/dev/null)" = "running" ]; then
            log "success" "Coolify container is running"
            break
        fi
        attempt=$((attempt+1))
        log "info" "Waiting for Coolify container to start (attempt $attempt/$max_attempts)..."
        sleep 10
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log "warn" "Coolify did not start in the expected time. Will still attempt to initialize."
    fi
    
    # Give the container a moment to fully initialize
    sleep 10
    
    # Run migrations
    log "info" "Running Coolify database migrations..."
    if docker exec coolify-${DOMAIN_BASE} php artisan migrate --force; then
        log "success" "Coolify database migrations completed successfully"
    else
        log "warn" "Coolify database migrations may have encountered issues"
    fi
    
    # Generate application key
    log "info" "Generating Coolify application key..."
    if docker exec coolify-${DOMAIN_BASE} php artisan key:generate --force; then
        log "success" "Coolify application key generated successfully"
    else
        log "warn" "Coolify application key generation may have encountered issues"
    fi
    
    # Seed the database
    log "info" "Seeding Coolify database..."
    if docker exec coolify-${DOMAIN_BASE} php artisan db:seed --force; then
        log "success" "Coolify database seeded successfully"
    else
        log "warn" "Coolify database seeding may have encountered issues"
    fi
}

# Start services
log "info" "Starting services..."
docker-compose up -d

# Wait for services to be healthy
log "info" "Waiting for services to be ready..."
sleep 5

# Initialize Coolify
initialize_coolify

# Display access URLs
log "success" "Services are ready!"
echo -e "\nAccess URLs:"
echo -e "${GREEN}LLM API (Ollama):${NC} http://localhost:${OLLAMA_PORT:-11434}"
echo -e "${GREEN}OpenWebUI:${NC} http://localhost:3333"
echo -e "${GREEN}Traefik Dashboard:${NC} http://localhost:8080"
echo -e "${GREEN}Rustpad:${NC} http://localhost:${RUSTPAD_PORT:-3030}"
echo -e "${GREEN}Grafana:${NC} http://localhost:3000"
echo -e "${GREEN}Prometheus:${NC} http://localhost:9090"
echo -e "${GREEN}Loki:${NC} http://localhost:3100"
echo -e "${GREEN}Authelia:${NC} http://localhost:9091"
echo -e "${GREEN}n8n:${NC} http://localhost:5678"
echo -e "${GREEN}Uptime Kuma:${NC} http://localhost:3001"
echo -e "${GREEN}Vaultwarden:${NC} http://localhost:80 (via Traefik)"
echo -e "${GREEN}Matrix/Conduit:${NC} http://localhost:6167"
echo -e "${GREEN}RustDesk:${NC} Relay: ${RUSTDESK_RELAY_PORT:-21117}, ID: ${RUSTDESK_ID_PORT:-21119}"
echo -e "${GREEN}Syncthing:${NC} http://localhost:8384"
echo -e "${GREEN}Postiz:${NC} http://localhost:5000 (via Traefik)"
echo -e "${GREEN}MinIO API:${NC} http://localhost:9000"
echo -e "${GREEN}MinIO Console:${NC} http://localhost:9001"
echo -e "${GREEN}Spacedrive:${NC} http://localhost:8081"
echo -e "${GREEN}Coolify:${NC} http://localhost:8443"
echo -e "${GREEN}Home Assistant:${NC} http://localhost:8123"
echo -e "${GREEN}Huginn:${NC} http://localhost:3010"
echo -e "${GREEN}WhoDB:${NC} http://localhost:8082"

if [[ -n "${DOMAIN:-}" ]]; then
    echo -e "\nRemote Access URLs (requires DNS setup):"
    echo -e "${GREEN}OpenWebUI:${NC} https://chat.${DOMAIN}"
    echo -e "${GREEN}Traefik Dashboard:${NC} https://traefik.${DOMAIN}"
    echo -e "${GREEN}Rustpad:${NC} https://pad.${DOMAIN}"
    echo -e "${GREEN}Grafana:${NC} https://grafana.${DOMAIN}"
    echo -e "${GREEN}Prometheus:${NC} https://metrics.${DOMAIN}"
    echo -e "${GREEN}Loki:${NC} https://logs.${DOMAIN}"
    echo -e "${GREEN}Authelia:${NC} https://auth.${DOMAIN}"
    echo -e "${GREEN}n8n:${NC} https://n8n.${DOMAIN}"
    echo -e "${GREEN}Uptime Kuma:${NC} https://status.${DOMAIN}"
    echo -e "${GREEN}Vaultwarden:${NC} https://vault.${DOMAIN}"
    echo -e "${GREEN}Matrix/Conduit:${NC} https://matrix.${DOMAIN}"
    echo -e "${GREEN}RustDesk:${NC} https://remote.${DOMAIN}"
    echo -e "${GREEN}Syncthing:${NC} https://sync.${DOMAIN}"
    echo -e "${GREEN}Postiz:${NC} https://notes.${DOMAIN}"
    echo -e "${GREEN}MinIO API:${NC} https://s3.${DOMAIN}"
    echo -e "${GREEN}MinIO Console:${NC} https://s3-console.${DOMAIN}"
    echo -e "${GREEN}Spacedrive:${NC} https://files.${DOMAIN}"
    echo -e "${GREEN}Coolify:${NC} https://coolify.${DOMAIN}"
    echo -e "${GREEN}Home Assistant:${NC} https://home.${DOMAIN}"
    echo -e "${GREEN}Huginn:${NC} https://huginn.${DOMAIN}"
    echo -e "${GREEN}WhoDB:${NC} https://db-explorer.${DOMAIN}"
fi

log "success" "Rebuild complete!"
