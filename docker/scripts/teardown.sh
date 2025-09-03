#!/usr/bin/env bash

# Set strict error handling
set -euo pipefail
IFS=$'\n\t'

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to modify AWS CLI commands to use the selected profile
aws_cmd() {
    if [ -n "${AWS_PROFILE:-}" ]; then
        log "debug" "Running AWS command with profile: $AWS_PROFILE"
        aws --profile "$AWS_PROFILE" "$@"
    else
        aws "$@"
    fi
}

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

# Function to get public IP using multiple methods
get_public_ip() {
    local ip

    # Method 1: Using curl with various IP services
    for service in "https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com"; do
        ip=$(curl -s "$service" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    done

    # Method 2: Using dig with various DNS providers
    for provider in "@resolver1.opendns.com" "@ns1.google.com" "@1.1.1.1"; do
        ip=$(dig +short myip.opendns.com "$provider" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    done

    return 1
}

# Function to remove DNS record
remove_dns_record() {
    local subdomain=$1
    local record_name="${subdomain}.${DOMAIN}"
    [[ "${record_name}" != *"." ]] && record_name="${record_name}."
    
    # Get current IP to remove the record
    local ip_address=$(get_public_ip)
    if [[ ! $ip_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "error" "Failed to get valid public IP address"
        return 1
    fi

    log "info" "Removing DNS record for ${record_name}..."

    # Remove record using AWS CLI with proper JSON formatting
    local change_batch=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "${record_name}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "${ip_address}"
          }
        ]
      }
    }
  ]
}
EOF
)

    if ! aws_cmd route53 change-resource-record-sets \
        --hosted-zone-id "$ZONE_ID" \
        --change-batch "$change_batch" >/dev/null 2>&1; then
        log "error" "Failed to remove DNS record for ${record_name}"
        return 1
    fi

    log "success" "Removed DNS record for ${record_name}"
    return 0
}

# Function to clean up DNS records
cleanup_dns_records() {
    if [ -z "${DOMAIN:-}" ]; then
        log "warn" "DOMAIN not set, skipping DNS cleanup"
        return 0
    fi

    if [ -z "${ZONE_ID:-}" ]; then
        log "info" "ZONE_ID not set, attempting to retrieve from AWS..."
        ZONE_ID=$(aws_cmd route53 list-hosted-zones-by-name --dns-name "${DOMAIN}." --max-items 1 --query 'HostedZones[0].Id' --output text 2>/dev/null)
        if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "None" ]; then
            log "warn" "Could not find Route53 zone ID for ${DOMAIN}, skipping DNS cleanup"
            return 0
        fi
        ZONE_ID=${ZONE_ID#/hostedzone/}
        log "success" "Retrieved ZONE_ID: ${ZONE_ID}"
    fi

    log "info" "Cleaning up DNS records..."
    local subdomains=("api" "chat" "traefik" "pad" "metrics" "grafana" "logs" "auth" "n8n" "status" "vault" "matrix" "remote" "sync" "notes" "db" "vector" "s3" "s3-console" "files" "home" "huginn" "db-explorer")
    for subdomain in "${subdomains[@]}"; do
        if ! remove_dns_record "$subdomain"; then
            log "warn" "Failed to remove DNS record for ${subdomain}.${DOMAIN}, continuing..."
        fi
    done
}

# Function to safely remove Docker resources
remove_docker_resources() {
    log "info" "Removing Docker containers and volumes..."
    
    # Check for container name conflicts first
    log "info" "Checking for container name conflicts..."
    
    # Get list of services from docker-compose.yml
    local services=$(docker-compose config --services 2>/dev/null || echo "")
    
    for service in $services; do
        container_name="${service}-${DOMAIN_BASE}"
        
        # Check if container exists but is not managed by our docker-compose project
        if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
            label=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$container_name" 2>/dev/null || echo "")
            
            if [ "$label" != "llm-docker" ]; then
                log "warn" "Found conflicting container: ${container_name}"
                log "info" "This container is not managed by our project and will be left untouched"
            fi
        fi
    done
    
    # Stop and remove containers
    log "info" "Stopping and removing containers managed by this project..."
    docker-compose down --volumes --remove-orphans || true
    
    # Remove volumes
    local volumes=(
        "llm-docker_ollama_data"
        "llm-docker_webui_data"
        "llm-docker_postgres_data"
        "llm-docker_redis_data"
        "llm-docker_vector_data"
        "llm-docker_prometheus_data"
        "llm-docker_grafana_data"
        "llm-docker_loki_data"
        "llm-docker_authelia_data"
        "llm-docker_n8n_data"
        "llm-docker_uptime_kuma_data"
        "llm-docker_vaultwarden_data"
        "llm-docker_matrix_data"
        "llm-docker_rustdesk_data"
        "llm-docker_syncthing_data"
        "llm-docker_postiz_data"
        "llm-docker_minio_data"
        "llm-docker_spacedrive_data"
        "llm-docker_homeassistant_config"
        "llm-docker_huginn_data"
        "llm-docker_whodb_data"
    )
    
    for volume in "${volumes[@]}"; do
        if docker volume ls -q | grep -q "^${volume}$"; then
            log "info" "Removing volume: ${volume}"
            docker volume rm "${volume}" || true
        fi
    done
    
    # Check network for active containers
    if docker network ls | grep -q llm_network; then
        log "info" "Checking llm_network for active containers..."
        
        # Check if network has active endpoints
        if docker network inspect llm_network | grep -q "Containers\":{}" || docker network inspect llm_network | grep -q "\"Containers\": {}"; then
            # Network has no containers, safe to remove
            log "info" "Removing llm_network..."
            docker network rm llm_network || true
        else
            # Network has active containers
            log "warn" "Network llm_network has active containers"
            
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
            
            # Try to remove network again
            log "info" "Removing llm_network after disconnecting external containers..."
            docker network rm llm_network || log "warn" "Could not remove llm_network, it may still have active endpoints"
        fi
    fi
    
    log "success" "Docker resources removed"
}

# Function to clean up files
cleanup_files() {
    log "info" "Cleaning up files..."
    files_to_remove=(
        "credentials.txt"
    )

    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file" && log "success" "Removed file: $file" || log "warn" "Failed to remove file: $file"
        else
            log "info" "File not found: $file"
        fi
    done

    # Restore Let's Encrypt certificates if they were backed up
    if [ -f "traefik/certificates_backup/acme.json" ]; then
        log "info" "Restoring Let's Encrypt certificates..."
        mkdir -p traefik/certificates
        mv traefik/certificates_backup/acme.json traefik/certificates/
        chmod 600 traefik/certificates/acme.json
        rmdir traefik/certificates_backup
        log "success" "Let's Encrypt certificates restored"
    fi
}

# Main execution
log "info" "Starting cleanup process..."

# Check if AWS_PROFILE is set (which happens when leo alias is run)
if [[ -n "${AWS_PROFILE:-}" ]]; then
    log "info" "AWS profile is set to ${AWS_PROFILE}, proceeding with AWS operations..."
    cleanup_dns_records || log "warn" "DNS cleanup failed"
else
    log "warn" "AWS_PROFILE is not set. If you have an AWS profile function or alias (like 'leo'), please run it before executing this script."
    log "info" "Continuing without AWS authentication. DNS cleanup will be skipped."
fi

remove_docker_resources
cleanup_files

log "success" "Teardown complete"
echo -e "\n${GREEN}System has been reset. You can now run setup.sh for a fresh installation.${NC}\n"
