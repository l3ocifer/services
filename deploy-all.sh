#!/bin/bash

# Homelab Services Deployment Script (Idempotent)
# Deploys all homelab services including consolidated production projects
# Author: Leo Paska
# Version: 2.0.0

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_DIR="/home/l3o/git/homelab"
PRODUCTION_DIR="/home/l3o/git/production"
ALEF_DIR="$HOMELAB_DIR/alef"
SERVICES_DIR="$HOMELAB_DIR/services"
LOG_FILE="/tmp/homelab-deploy.log"

# Service categories
declare -A SERVICE_CATEGORIES=(
    ["infrastructure"]="Core infrastructure services"
    ["ai_ml"]="AI and machine learning services"
    ["monitoring"]="Monitoring and observability"
    ["productivity"]="Productivity and automation tools"
    ["communication"]="Communication and collaboration"
    ["security"]="Security and authentication"
    ["storage"]="Storage and backup services"
    ["development"]="Development and deployment tools"
)

# Service definitions
declare -A SERVICES=(
    # Infrastructure
    ["traefik"]="infrastructure:Reverse proxy and SSL termination"
    ["postgres"]="infrastructure:Primary database service"
    ["redis"]="infrastructure:Caching and session storage"
    ["minio"]="infrastructure:S3-compatible object storage"
    
    # AI/ML
    ["ollama"]="ai_ml:Local LLM inference server"
    ["webui"]="ai_ml:AI chat interface"
    ["whodb"]="ai_ml:Database exploration with AI"
    
    # Monitoring
    ["prometheus"]="monitoring:Metrics collection"
    ["grafana"]="monitoring:Visualization dashboards"
    ["loki"]="monitoring:Log aggregation"
    ["uptime-kuma"]="monitoring:Service monitoring"
    ["node-exporter"]="monitoring:System metrics"
    
    # Productivity
    ["n8n"]="productivity:Workflow automation"
    ["coolify"]="productivity:Container deployment platform"
    ["syncthing"]="productivity:File synchronization"
    ["rustdesk"]="productivity:Remote desktop access"
    ["homeassistant"]="productivity:Home automation"
    ["huginn"]="productivity:Event processing"
    ["postiz"]="productivity:Note-taking application"
    
    # Communication
    ["conduit"]="communication:Matrix server"
    ["element"]="communication:Matrix client"
    ["rustpad"]="communication:Collaborative editor"
    
    # Security
    ["authelia"]="security:SSO and 2FA"
    ["vaultwarden"]="security:Password management"
    
    # Storage
    ["spacedrive"]="storage:File management"
    
    # Development
    ["vector"]="development:Log processing"
)

# Production projects
declare -A PRODUCTION_PROJECTS=(
    ["discoverlocal_ai"]="Node.js/Next.js AI Platform"
    ["hyvapaska_com"]="Next.js E-commerce Platform"
    ["potluck_pub"]="Rust Microservices Social Platform"
    ["omnilemma_com"]="Rust/Dioxus Meal Planning PWA"
    ["theblink_live"]="Next.js Live Streaming Platform"
)

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as correct user
    if [[ "$USER" != "l3o" ]]; then
        error "This script must be run as user 'l3o'"
    fi
    
    # Check if homelab directory exists
    if [[ ! -d "$HOMELAB_DIR" ]]; then
        error "Homelab directory not found: $HOMELAB_DIR"
    fi
    
    # Check if production directory exists
    if [[ ! -d "$PRODUCTION_DIR" ]]; then
        error "Production directory not found: $PRODUCTION_DIR"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed or not in PATH"
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
    fi
    
    # Check systemd services
    check_systemd_services
    
    # Check Ansible
    if ! command -v ansible-playbook &> /dev/null; then
        warning "Ansible not found. Some services may not deploy properly."
    fi
    
    # Check system resources
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_mem -lt 32 ]]; then
        warning "System has less than 32GB RAM. Some services may not perform optimally."
    fi
    
    success "Prerequisites check completed"
}

# Check critical systemd services
check_systemd_services() {
    log "Checking systemd services..."
    
    # Check Ollama
    if systemctl is-active --quiet ollama; then
        success "Ollama systemd service is running"
    else
        warning "Ollama systemd service is not running. AI features may be limited."
        log "To install Ollama: curl -fsSL https://ollama.ai/install.sh | sh"
    fi
    
    # Check Docker
    if systemctl is-active --quiet docker; then
        success "Docker systemd service is running"
    else
        error "Docker systemd service is not running"
    fi
    
    # Check SSH (optional but good to verify)
    if systemctl is-active --quiet ssh; then
        success "SSH systemd service is running"
    else
        warning "SSH systemd service is not running"
    fi
}

# Check if service is running and healthy
is_service_healthy() {
    local service_name="$1"
    local compose_file="${2:-docker-compose.yml}"
    
    # Check if container is running
    if ! docker-compose -f "$compose_file" ps "$service_name" | grep -q "Up"; then
        return 1
    fi
    
    # Check health status if healthcheck is defined
    local health_status=$(docker-compose -f "$compose_file" ps "$service_name" | grep "$service_name" | awk '{print $4}')
    if [[ "$health_status" == *"unhealthy"* ]]; then
        return 1
    fi
    
    return 0
}

# Deploy service if not running or unhealthy
deploy_service_if_needed() {
    local service_name="$1"
    local compose_file="${2:-docker-compose.yml}"
    local wait_time="${3:-10}"
    
    if is_service_healthy "$service_name" "$compose_file"; then
        log "Service $service_name is already running and healthy"
        return 0
    fi
    
    log "Deploying service: $service_name"
    docker-compose -f "$compose_file" up -d "$service_name"
    
    if [[ $wait_time -gt 0 ]]; then
        log "Waiting $wait_time seconds for $service_name to start..."
        sleep "$wait_time"
    fi
    
    # Verify deployment
    if is_service_healthy "$service_name" "$compose_file"; then
        success "Service $service_name deployed successfully"
    else
        warning "Service $service_name deployed but may not be fully healthy yet"
    fi
}

# Deploy core infrastructure (idempotent)
deploy_infrastructure() {
    log "Deploying core infrastructure services (idempotent)..."
    
    cd "$SERVICES_DIR/docker"
    
    # Check if .env file exists
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            cp .env.example .env
            warning "Created .env file from .env.example. Please review and update configuration."
        else
            error "No .env file found and no .env.example to copy from"
        fi
    fi
    
    # Deploy services in dependency order
    deploy_service_if_needed "traefik" "docker-compose.yml" 10
    deploy_service_if_needed "neon-postgres" "docker-compose.yml" 15
    deploy_service_if_needed "redis" "docker-compose.yml" 10
    deploy_service_if_needed "authelia" "docker-compose.yml" 10
    deploy_service_if_needed "vaultwarden" "docker-compose.yml" 10
    deploy_service_if_needed "minio" "docker-compose.yml" 10
    
    success "Core infrastructure deployment completed"
}

# Deploy AI/ML services (idempotent)
deploy_ai_ml() {
    log "Deploying AI/ML services (idempotent)..."
    
    cd "$SERVICES_DIR/docker"
    
    # Deploy AI/ML services
    deploy_service_if_needed "webui" "docker-compose.yml" 15
    deploy_service_if_needed "whodb" "docker-compose.yml" 10
    deploy_service_if_needed "librechat" "docker-compose.yml" 20
    deploy_service_if_needed "mongo" "docker-compose.yml" 15
    
    # Note: Ollama is commented out in the compose file, would need to be enabled
    # deploy_service_if_needed "ollama" "docker-compose.yml" 30
    
    success "AI/ML services deployment completed"
}

# Deploy monitoring services (idempotent)
deploy_monitoring() {
    log "Deploying monitoring services (idempotent)..."
    
    cd "$SERVICES_DIR/docker"
    
    # Deploy monitoring services
    deploy_service_if_needed "prometheus" "docker-compose.yml" 15
    deploy_service_if_needed "grafana" "docker-compose.yml" 15
    deploy_service_if_needed "loki" "docker-compose.yml" 10
    deploy_service_if_needed "uptime-kuma" "docker-compose.yml" 10
    deploy_service_if_needed "node-exporter" "docker-compose.yml" 5
    deploy_service_if_needed "umami" "docker-compose.yml" 10
    
    success "Monitoring services deployment completed"
}

# Deploy productivity services (idempotent)
deploy_productivity() {
    log "Deploying productivity services (idempotent)..."
    
    cd "$SERVICES_DIR/docker"
    
    # Deploy each service individually with health checks
    deploy_service_if_needed "n8n" "docker-compose.yml" 15
    deploy_service_if_needed "coolify" "docker-compose.yml" 20
    deploy_service_if_needed "syncthing" "docker-compose.yml" 10
    deploy_service_if_needed "rustdesk-hbbs" "docker-compose.yml" 10
    deploy_service_if_needed "rustdesk-hbbr" "docker-compose.yml" 10
    deploy_service_if_needed "homeassistant" "docker-compose.yml" 15
    deploy_service_if_needed "huginn" "docker-compose.yml" 15
    deploy_service_if_needed "postiz" "docker-compose.yml" 10
    
    success "Productivity services deployment completed"
}

# Deploy communication services (idempotent)
deploy_communication() {
    log "Deploying communication services (idempotent)..."
    
    cd "$SERVICES_DIR/docker"
    
    # Deploy each service individually with health checks
    deploy_service_if_needed "conduit" "docker-compose.yml" 15
    deploy_service_if_needed "element" "docker-compose.yml" 10
    deploy_service_if_needed "rustpad" "docker-compose.yml" 10
    
    success "Communication services deployment completed"
}

# Deploy storage services (idempotent)
deploy_storage() {
    log "Deploying storage services (idempotent)..."
    
    cd "$SERVICES_DIR/docker"
    
    # Deploy each service individually with health checks
    deploy_service_if_needed "spacedrive" "docker-compose.yml" 10
    
    success "Storage services deployment completed"
}

# Deploy development services (idempotent)
deploy_development() {
    log "Deploying development services (idempotent)..."
    
    cd "$SERVICES_DIR/docker"
    
    # Deploy development tools
    deploy_service_if_needed "vector" "docker-compose.yml" 10
    
    success "Development services deployment completed"
}

# Deploy additional services (idempotent)
deploy_additional_services() {
    log "Deploying additional services (idempotent)..."
    
    cd "$SERVICES_DIR/docker"
    
    # Deploy media and communication services
    deploy_service_if_needed "jellyfin" "docker-compose.yml" 15
    deploy_service_if_needed "jitsi-web" "docker-compose.yml" 20
    deploy_service_if_needed "pihole" "docker-compose.yml" 10
    
    success "Additional services deployment completed"
}

# Deploy consolidated production services
deploy_consolidated_production() {
    log "Deploying consolidated production services..."
    
    cd "$PRODUCTION_DIR"
    
    # Check if consolidated deployment script exists
    if [[ -f "deploy-all.sh" ]]; then
        log "Using consolidated production deployment..."
        ./deploy-all.sh --infra-only
        success "Consolidated production infrastructure deployed"
    else
        warning "Consolidated deployment script not found. Falling back to individual project deployment."
        deploy_individual_production_projects
    fi
}

# Deploy individual production projects (fallback)
deploy_individual_production_projects() {
    log "Deploying individual production projects..."
    
    cd "$PRODUCTION_DIR"
    
    # Deploy each project individually
    for project in "${!PRODUCTION_PROJECTS[@]}"; do
        local project_dir="$PRODUCTION_DIR/$project"
        if [[ -d "$project_dir" && -f "$project_dir/docker-compose.yml" ]]; then
            log "Deploying $project..."
            cd "$project_dir"
            docker-compose up -d
        fi
    done
    
    success "Individual production projects deployed"
}

# Deploy production projects (main function)
deploy_production_projects() {
    log "Deploying production projects..."
    
    # Use the consolidated deployment script
    if [[ -f "$PRODUCTION_DIR/deploy-all.sh" ]]; then
        cd "$PRODUCTION_DIR"
        ./deploy-all.sh
        success "Production projects deployed via consolidated script"
    else
        warning "Consolidated deployment script not found. Deploying projects individually..."
        deploy_individual_production_projects
    fi
}

# Deploy Ansible services (if available)
deploy_ansible_services() {
    log "Checking for Ansible services..."
    
    if [[ -d "$SERVICES_DIR/ansible" ]]; then
        cd "$SERVICES_DIR/ansible"
        
        if [[ -f "site.yml" ]]; then
            log "Deploying Ansible services..."
            ansible-playbook site.yml
            success "Ansible services deployed"
        else
            warning "Ansible site.yml not found"
        fi
    else
        warning "Ansible directory not found"
    fi
}

# Deploy Alef system services
deploy_alef_services() {
    log "Deploying Alef system services..."
    
    if [[ -d "$ALEF_DIR" ]]; then
        cd "$ALEF_DIR"
        
        if [[ -f "install-services.sh" ]]; then
            log "Installing Alef systemd services..."
            sudo ./install-services.sh
            success "Alef system services installed"
        else
            warning "Alef install-services.sh not found"
        fi
    else
        warning "Alef directory not found"
    fi
}

# Check service health
check_service_health() {
    log "Checking service health..."
    
    local failed_services=()
    
    # Check homelab services
    cd "$SERVICES_DIR/docker"
    local running_services=$(docker-compose ps --services --filter "status=running" | wc -l)
    local total_services=$(docker-compose ps --services | wc -l)
    
    if [[ $running_services -lt $total_services ]]; then
        warning "Some homelab services are not running ($running_services/$total_services)"
    else
        success "All homelab services are running ($running_services/$total_services)"
    fi
    
    # Check production projects
    for project in "${!PRODUCTION_PROJECTS[@]}"; do
        local project_dir="$PRODUCTION_DIR/$project"
        if [[ -d "$project_dir" && -f "$project_dir/docker-compose.yml" ]]; then
            cd "$project_dir"
            if ! docker-compose ps | grep -q "Up"; then
                failed_services+=("$project")
            fi
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        success "All production projects are healthy"
    else
        warning "Some production projects failed: ${failed_services[*]}"
    fi
}

# Display service URLs
display_service_urls() {
    log "Service URLs:"
    echo ""
    echo -e "${GREEN}=== SYSTEMD SERVICES ===${NC}"
    echo "Ollama API: http://localhost:11434 (if installed) | https://api.leopaska.com (external)"
    echo "Docker: systemctl status docker"
    echo "SSH: Port 22"
    echo ""
    echo -e "${GREEN}=== CORE INFRASTRUCTURE ===${NC}"
    echo "Traefik Dashboard: http://localhost:8080 (local) | https://traefik.leopaska.com (external)"
    echo "PostgreSQL (Homelab): localhost:5432 (local only)"
    echo "Redis (Homelab): localhost:6379 (local only)"
    echo "MinIO Console: http://localhost:9001 (local) | https://s3-console.leopaska.com (external)"
    echo ""
    
    echo -e "${GREEN}=== AI/ML SERVICES ===${NC}"
    echo "OpenWebUI: http://localhost:11333 (local) | https://chat.leopaska.com (external)"
    echo "WhoDB: http://localhost:5005 (local) | https://db-explorer.leopaska.com (external)"
    echo "LibreChat: http://localhost:3080 (local) | https://librechat.leopaska.com (external)"
    echo "Ollama: http://localhost:11434 (if enabled) | https://api.leopaska.com (external)"
    echo ""
    
    echo -e "${GREEN}=== MONITORING ===${NC}"
    echo "Grafana: http://localhost:3002 (local) | https://grafana.leopaska.com (external)"
    echo "Prometheus: http://localhost:7090 (local) | https://metrics.leopaska.com (external)"
    echo "Loki: http://localhost:7100 (local) | https://logs.leopaska.com (external)"
    echo "Uptime Kuma: http://localhost:3001 (local) | https://status.leopaska.com (external)"
    echo "Node Exporter: http://localhost:7101 (local only)"
    echo "Umami Analytics: http://localhost:3006 (local) | https://analytics.leopaska.com (external)"
    echo ""
    
    echo -e "${GREEN}=== PRODUCTIVITY TOOLS ===${NC}"
    echo "n8n: http://localhost:5678 (local) | https://n8n.leopaska.com (external)"
    echo "Coolify: http://localhost:8000 (local) | https://coolify.leopaska.com (external)"
    echo "Syncthing: http://localhost:6834 (local) | https://sync.leopaska.com (external)"
    echo "RustDesk: http://localhost:6118 (local) | https://remote.leopaska.com (external)"
    echo "Home Assistant: http://localhost:3010 (local) | https://home.leopaska.com (external)"
    echo "Huginn: http://localhost:3011 (local) | https://huginn.leopaska.com (external)"
    echo "Postiz: http://localhost:3000 (local) | https://notes.leopaska.com (external)"
    echo ""
    
    echo -e "${GREEN}=== COMMUNICATION ===${NC}"
    echo "Matrix (Conduit): http://localhost:6167 (local) | https://matrix.leopaska.com (external)"
    echo "Element: http://localhost:6099 (local) | https://chat-matrix.leopaska.com (external)"
    echo "RustPad: http://localhost:3030 (local) | https://pad.leopaska.com (external)"
    echo ""
    
    echo -e "${GREEN}=== SECURITY ===${NC}"
    echo "Authelia: http://localhost:9091 (local) | https://auth.leopaska.com (external)"
    echo "Vaultwarden: http://localhost:80 (local) | https://vault.leopaska.com (external)"
    echo ""
    
    echo -e "${GREEN}=== STORAGE ===${NC}"
    echo "SpaceDrive: http://localhost:8081 (local) | https://drive.leopaska.com (external)"
    echo ""
    
    echo -e "${GREEN}=== MEDIA & COMMUNICATION ===${NC}"
    echo "Jellyfin: http://localhost:8096 (local) | https://media.leopaska.com (external)"
    echo "Jitsi Meet: http://localhost:8083 (local) | https://meet.leopaska.com (external)"
    echo "Pi-hole: http://localhost:8082 (local only)"
    echo ""
    
    echo -e "${GREEN}=== DEVELOPMENT TOOLS ===${NC}"
    echo "Adminer: http://localhost:8084 (local) | https://admin.leopaska.com (external)"
    echo "Redis Commander: http://localhost:8085 (local) | https://redis-admin.leopaska.com (external)"
    echo "PgAdmin: http://localhost:8086 (local) | https://pgadmin.leopaska.com (external)"
    echo ""
    
    echo -e "${GREEN}=== PRODUCTION PROJECTS ===${NC}"
    echo "DiscoverLocal AI: http://localhost:3005 (local) | https://discoverlocal.leopaska.com (external)"
    echo "HyvaPaska: http://localhost:3003 (local) | https://hyvapaska.com (external)"
    echo "Potluck: http://localhost:8100 (local) | https://potluck.pub (external)"
    echo "TheBlink Live: http://localhost:3004 (local) | https://theblink.live (external)"
    echo "Omnilemma: Static files (build required) | https://omnilemma.com (external)"
    echo ""
    echo -e "${YELLOW}Note: Some services may require VPN access for full functionality${NC}"
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    # Add any cleanup tasks here
}

# Main deployment function
main() {
    log "Starting homelab services deployment..."
    
    # Set up signal handlers
    trap cleanup EXIT
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy services in order
    deploy_infrastructure
    deploy_ai_ml
    deploy_monitoring
    deploy_productivity
    deploy_communication
    deploy_storage
    deploy_development
    deploy_additional_services
    
    # Deploy consolidated production infrastructure first
    deploy_consolidated_production
    
    # Deploy production projects
    deploy_production_projects
    
    # Deploy additional services
    deploy_ansible_services
    deploy_alef_services
    
    # Check service health
    check_service_health
    
    # Display service URLs
    display_service_urls
    
    success "Homelab deployment completed!"
    log "Deployment log saved to: $LOG_FILE"
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Homelab Services Deployment Script"
        echo ""
        echo "Usage: $0 [OPTIONS] [CATEGORY]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --check        Check prerequisites only"
        echo "  --health       Check service health only"
        echo "  --urls         Display service URLs only"
        echo "  --clean        Clean up all services"
        echo "  --list         List available service categories"
        echo ""
        echo "Categories:"
        for category in "${!SERVICE_CATEGORIES[@]}"; do
            echo "  - $category: ${SERVICE_CATEGORIES[$category]}"
        done
        echo ""
        echo "Production Projects:"
        for project in "${!PRODUCTION_PROJECTS[@]}"; do
            echo "  - $project: ${PRODUCTION_PROJECTS[$project]}"
        done
        exit 0
        ;;
    "--check")
        check_prerequisites
        exit 0
        ;;
    "--health")
        check_service_health
        exit 0
        ;;
    "--urls")
        display_service_urls
        exit 0
        ;;
    "--list")
        echo "Available service categories:"
        for category in "${!SERVICE_CATEGORIES[@]}"; do
            echo "  $category: ${SERVICE_CATEGORIES[$category]}"
        done
        exit 0
        ;;
    "--clean")
        log "Cleaning up all services..."
        cd "$SERVICES_DIR/docker" && docker-compose down
        for project in "${!PRODUCTION_PROJECTS[@]}"; do
            project_dir="$PRODUCTION_DIR/$project"
            if [[ -d "$project_dir" && -f "$project_dir/docker-compose.yml" ]]; then
                cd "$project_dir" && docker-compose down
            fi
        done
        success "Cleanup completed"
        exit 0
        ;;
    "infrastructure")
        check_prerequisites
        deploy_infrastructure
        ;;
    "ai_ml")
        check_prerequisites
        deploy_ai_ml
        ;;
    "monitoring")
        check_prerequisites
        deploy_monitoring
        ;;
    "productivity")
        check_prerequisites
        deploy_productivity
        ;;
    "communication")
        check_prerequisites
        deploy_communication
        ;;
    "storage")
        check_prerequisites
        deploy_storage
        ;;
    "development")
        check_prerequisites
        deploy_development
        ;;
    "production")
        check_prerequisites
        deploy_production_projects
        ;;
    "")
        main
        ;;
    *)
        error "Unknown category: $1. Use --help for usage information."
        ;;
esac
