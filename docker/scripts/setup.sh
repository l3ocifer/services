#!/usr/bin/env bash

# This script sets up the Docker environment with the latest stable versions
# When run, it will pull the latest images for all services defined in docker-compose.yml
# Services using the 'latest' tag will get the most recent stable version

# Ensure we're running in bash 4 or higher for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: This script requires bash version 4 or higher"
    echo "Current version: $BASH_VERSION"
    echo "On macOS, you can install a newer version of bash with: brew install bash"
    exit 1
fi

set -euo pipefail
IFS=$'\n\t'

# Define leo function for AWS authentication
leo() {
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        echo "AWS CLI is not installed. Please install it first."
        return 1
    }
    
    # Configure AWS credentials - this is what the leo function should do
    # Adjust these commands based on your actual authentication method
    export AWS_PROFILE=default
    
    # Verify authentication worked
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "AWS authentication failed. Please check your credentials."
        return 1
    fi
    
    echo "Successfully authenticated with AWS as $(aws sts get-caller-identity --query 'Arn' --output text)"
    return 0
}

# Cleanup function to handle script interruption
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Script was interrupted or encountered an error (exit code: $exit_code)"
        echo "You can safely run the script again to continue setup"
    fi
    exit $exit_code
}

# Set trap for script interruption
trap cleanup EXIT INT TERM

# Colors for output
if [ -t 1 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    NC=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    NC=""
fi

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     if grep -q Microsoft /proc/version; then
                    OS='WSL'
                else
                    OS='LINUX'
                fi
                ;;
    Darwin*)    OS='MAC';;
    *)          OS='UNKNOWN';;
esac

# Logging functions
log() {
    local level=$1
    local msg="${2:-}"  # Add default empty value to prevent unbound variable
    local mark=""
    case $level in
        "success")
            mark="${GREEN}✓${NC}"
            ;;
        "error")
            mark="${RED}✗${NC}"
            ;;
        "info")
            mark="ℹ"
            ;;
        "warn")
            mark="${YELLOW}⚠${NC}"
            ;;
    esac
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $mark $msg"
}

# Check if a port is in use
check_port() {
    local port=$1
    local service=$2
    
    if lsof -i :"$port" > /dev/null 2>&1; then
        log "warn" "Port $port for $service is already in use"
        return 1
    else
        log "success" "Port $port for $service is available"
        return 0
    fi
}

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log "error" "$1 is required but not installed."
        exit 1
    fi
    log "success" "Found required command: $1"
}

# Find next available port
find_next_port() {
    local port=$1
    local var_name="${2:-PORT}"  # Default variable name if not provided
    local default_port="${3:-$port}"  # Default port if not provided
    
    while lsof -i :"$port" >/dev/null 2>&1; do
        port=$((port + 1))
    done
    
    log "success" "Found available port: $port"
    echo "$port"
}

# Function to update port if needed
update_port() {
    local port_name=$1
    local port_value=$2
    
    if lsof -i :"$port_value" >/dev/null 2>&1; then
        local new_port
        new_port=$(find_next_port "$port_value" "$port_name" "$port_value")
        log "info" "Port $port_value for $port_name is in use, using port $new_port"
        printf -v "$port_name" "%d" "$new_port"
        
        # Update .env file with new port
        if grep -q "^${port_name}=" .env; then
            sed -i "s/^${port_name}=.*/${port_name}=${new_port}/" .env
        else
            echo "${port_name}=${new_port}" >> .env
        fi
        
        return 0
    fi
    
    log "success" "Port $port_value for $port_name is available"
    printf -v "$port_name" "%d" "$port_value"
    return 0
}

# Check required commands
check_command docker
check_command docker-compose
check_command htpasswd
check_command aws
check_command lsof

# Verify AWS CLI configuration
if ! aws_cmd configure list > /dev/null 2>&1; then
    log "warn" "AWS CLI is not configured properly. If you have a profile function like 'leo', please run it before executing this script."
    log "info" "Continuing setup without AWS CLI configuration. DNS setup will be skipped."
else
    log "success" "AWS CLI is properly configured"
fi

# Load environment variables if .env exists
if [ -f .env ]; then
    source .env
fi

# Function to get domain name without TLD
get_domain_base() {
    local domain=$1
    echo "$domain" | sed -E 's/\.[^.]+$//'
}

# Function to generate a secure password
generate_password() {
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 14
}

# Function to update env file with proper credentials
update_env_credentials() {
    local domain_base=$1
    local admin_user="admin-${domain_base}"
    local traefik_pass=$(generate_password)
    local rustpad_pass=$(generate_password)
    local webui_pass=$(generate_password)
    
    # Generate hashed passwords using htpasswd
    local traefik_auth=$(htpasswd -nb "$admin_user" "$traefik_pass" | sed -e s/\\$/\\$\\$/g)
    local rustpad_auth=$(htpasswd -nb "$admin_user" "$rustpad_pass" | sed -e s/\\$/\\$\\$/g)
    local webui_auth=$(htpasswd -nb "$admin_user" "$webui_pass" | sed -e s/\\$/\\$\\$/g)
    
    # Update .env file with hashed passwords
    sed -i.bak \
        -e "s|^TRAEFIK_AUTH=.*|TRAEFIK_AUTH=$traefik_auth|" \
        -e "s|^RUSTPAD_AUTH=.*|RUSTPAD_AUTH=$rustpad_auth|" \
        -e "s|^WEBUI_AUTH=.*|WEBUI_AUTH=$webui_auth|" \
        .env
    rm -f .env.bak

    # Save plain text credentials to a secure file
    cat > credentials.txt << EOF
# Service Credentials
# ------------------
# Keep this file secure and delete after saving the passwords!

Username (same for all services): ${admin_user}

Traefik Dashboard Password: ${traefik_pass}
Rustpad Password: ${rustpad_pass}
WebUI Password: ${webui_pass}
EOF

    # Set restrictive permissions on credentials file
    chmod 600 credentials.txt
    
    # Display credentials to user
    log "success" "Generated new credentials (saved to credentials.txt):"
    log "info" "Username for all services: ${admin_user}"
    log "info" "Traefik Dashboard Password: ${traefik_pass}"
    log "info" "Rustpad Password: ${rustpad_pass}"
    log "info" "WebUI Password: ${webui_pass}"

    # Generate security.yml content with the same hashed passwords
    cat > traefik/config/security.yml << EOF
http:
  middlewares:
    security:
      headers:
        frameDeny: true
        sslRedirect: true
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
        customFrameOptionsValue: "SAMEORIGIN"
        customResponseHeaders:
          X-Robots-Tag: "none,noarchive,nosnippet,notranslate,noimageindex"
          server: ""
          X-Content-Type-Options: "nosniff"
          X-Frame-Options: "SAMEORIGIN"
          X-XSS-Protection: "1; mode=block"

    traefik-auth:
      basicAuth:
        users:
          - "${traefik_auth}"
        removeHeader: true

    rustpad-auth:
      basicAuth:
        users:
          - "${rustpad_auth}"
        removeHeader: true

    webui-auth:
      basicAuth:
        users:
          - "${webui_auth}"
        removeHeader: true

    local-only:
      ipWhiteList:
        sourceRange:
          - "127.0.0.1/32"  # localhost
          - "10.0.0.0/8"    # private network
          - "172.16.0.0/12" # private network (includes Docker)
          - "192.168.0.0/16" # private network
EOF

    log "success" "Updated credentials in .env and security.yml files"
}

# Function to create data directories
create_data_directories() {
    local data_dir="${DATA_DIR:-/mnt/data}"
    
    # Check if parent directory exists
    if [ ! -d "$data_dir" ]; then
        log "warn" "Data directory $data_dir does not exist and requires root privileges to create"
        log "info" "Automatically creating directory..."
        
        # Automatically run the command without prompting
        sudo mkdir -p "$data_dir" || { log "error" "Failed to create $data_dir"; exit 1; }
        sudo chown "$(whoami):$(whoami)" "$data_dir" || { log "error" "Failed to set permissions on $data_dir"; exit 1; }
        log "success" "Created data directory: $data_dir with correct permissions"
    else
        # Check if we have write permissions to the directory
        if [ ! -w "$data_dir" ]; then
            log "warn" "You don't have write permissions to $data_dir"
            log "info" "Automatically setting permissions..."
            
            # Automatically run the command without prompting
            sudo chown "$(whoami):$(whoami)" "$data_dir" || { log "error" "Failed to set permissions on $data_dir"; exit 1; }
            log "success" "Set correct permissions on $data_dir"
        else
            log "success" "Directory exists with correct permissions: $data_dir"
        fi
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
        "shared"  # For shared files accessible by Spacedrive
        "homeassistant"  # For Home Assistant configuration
        "huginn"  # For Huginn logs and data
        "coolify"
    )
    
    # Create each directory
    for dir in "${directories[@]}"; do
        if [ ! -d "$data_dir/$dir" ]; then
            log "info" "Creating service directory: $data_dir/$dir"
            mkdir -p "$data_dir/$dir"
            # Set appropriate permissions
            chmod 755 "$data_dir/$dir"
        else
            log "success" "Directory exists: $data_dir/$dir"
        fi
    done
    
    log "success" "All data directories created"
}

# Function to check if Ollama is installed on host
check_host_ollama() {
    if command -v ollama >/dev/null 2>&1; then
        log "success" "Found Ollama installation on host system"
        return 0
    fi
    log "info" "Ollama not found on host system"
    return 1
}

# Function to get model files from host
get_host_model_files() {
    local model=$1
    local host_ollama_dir="$HOME/.ollama"
    local model_files=()
    
    # Check for blobs directory
    if [ ! -d "$host_ollama_dir/models/blobs" ]; then
        log "error" "Host blobs directory not found: $host_ollama_dir/models/blobs"
        return 1
    fi
    
    # Check for manifests directory
    local manifest_dir="$host_ollama_dir/models/manifests/registry.ollama.ai/library"
    if [ ! -d "$manifest_dir" ]; then
        log "error" "Host manifest directory not found: $manifest_dir"
        return 1
    fi
    
    # Check if model manifest exists
    if [ ! -d "$manifest_dir/$model" ]; then
        log "error" "Model manifest not found: $manifest_dir/$model"
        return 1
    fi
    
    log "info" "Found model manifest for $model"
    echo "$manifest_dir/$model"
    return 0
}

# Function to copy model from host to container
copy_model_to_container() {
    local model=$1
    local container_name="ollama"
    
    log "info" "Copying model $model from host to container..."
    
    # Get host model path
    local model_path=$(get_host_model_files "$model")
    if [ $? -ne 0 ]; then
        log "error" "Failed to locate model files on host"
        return 1
    fi
    
    # Create temporary directory for the transfer
    local temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    
    # Create necessary directories in temp
    mkdir -p "$temp_dir/models/manifests/registry.ollama.ai/library"
    mkdir -p "$temp_dir/models/blobs"
    
    # Copy manifest files
    log "info" "Copying manifest files..."
    cp -r "$HOME/.ollama/models/manifests/registry.ollama.ai/library/$model" \
        "$temp_dir/models/manifests/registry.ollama.ai/library/"
    
    # Copy required blobs
    log "info" "Copying blob files..."
    if [ -d "$HOME/.ollama/models/blobs" ]; then
        cp -r "$HOME/.ollama/models/blobs" "$temp_dir/models/"
    fi
    
    # Copy to container
    log "info" "Transferring files to container..."
    docker cp "$temp_dir/models/." "$container_name:/root/.ollama/models/"
    if [ $? -eq 0 ]; then
        log "success" "Successfully copied model $model to container"
        return 0
    else
        log "error" "Failed to copy model $model to container"
        return 1
    fi
}

# Function to check if model exists on host
check_host_model() {
    local model=$1
    
    if ! check_host_ollama; then
        return 1
    fi
    
    if get_host_model_files "$model" > /dev/null 2>&1; then
        log "success" "Model $model found in host system"
        return 0
    fi
    return 1
}

# Function to check for running Ollama instances
check_ollama_instance() {
    log "info" "Checking for running Ollama instances..."
    
    # Check if Ollama is running as a system service
    if systemctl is-active --quiet ollama 2>/dev/null; then
        log "info" "Ollama is running as a system service on port 11434."
        return 1
    fi
    
    # Check if Ollama is running as a standalone process
    if pgrep -f "ollama serve" >/dev/null; then
        log "info" "Ollama is running as a standalone process on port 11434."
        return 1
    fi
    
    # Check if port 11434 is in use
    if lsof -i :11434 >/dev/null 2>&1; then
        log "info" "Port 11434 is in use, likely by an existing Ollama instance."
        return 1
    fi
    
    log "success" "No running Ollama instances found on port 11434"
    return 0
}

# Setup Ollama
setup_ollama() {
    log "info" "Setting up Ollama..."
    
    # Check for existing Ollama instances
    if check_ollama_instance; then
        # No existing Ollama instance, use Docker container
        log "info" "No existing Ollama instance found. Will deploy Ollama in Docker."
        
        # Set default port in .env if not already set
        if ! grep -q "^OLLAMA_PORT=" .env; then
            echo "OLLAMA_PORT=11434" >> .env
            log "info" "Using default Ollama port: 11434"
        fi
        
        # Ensure docker-compose.yml has the correct port
        if [ -f docker-compose.yml ]; then
            log "info" "Updating docker-compose.yml for containerized Ollama..."
            
            # Create a backup of the original file if it doesn't exist
            if [ ! -f docker-compose.yml.bak ]; then
                cp docker-compose.yml docker-compose.yml.bak
            fi
            
            # Update the port in the ollama service section
            sed -i -E "s/- \"[0-9]+:11434\"/- \"${OLLAMA_PORT:-11434}:11434\"/" docker-compose.yml
            
            # Uncomment the ollama service if it's commented out
            sed -i 's/^  #ollama:/  ollama:/' docker-compose.yml
            sed -i '/^  #  image: ollama/s/^  #  /  /' docker-compose.yml
            sed -i '/^  #    /s/^  #    /    /' docker-compose.yml
            
            log "success" "Updated docker-compose.yml for containerized Ollama"
        fi
        
        # Create Ollama models directory if it doesn't exist
        if [ ! -d "${DATA_DIR}/ollama" ]; then
            mkdir -p "${DATA_DIR}/ollama"
            log "info" "Created Ollama data directory: ${DATA_DIR}/ollama"
        fi
    else
        # Existing Ollama instance found, configure to use it
        log "info" "Existing Ollama instance found. Will integrate with it instead of deploying in Docker."
        
        # Update .env to use host network for Ollama
        if grep -q "^OLLAMA_PORT=" .env; then
            sed -i "s/^OLLAMA_PORT=.*/OLLAMA_PORT=11434/" .env
        else
            echo "OLLAMA_PORT=11434" >> .env
        fi
        
        # Modify docker-compose.yml to disable the Ollama service
        if [ -f docker-compose.yml ]; then
            log "info" "Updating docker-compose.yml to use host Ollama..."
            
            # Create a backup of the original file if it doesn't exist
            if [ ! -f docker-compose.yml.bak ]; then
                cp docker-compose.yml docker-compose.yml.bak
            fi
            
            # Comment out the ollama service in docker-compose.yml
            sed -i '/^  ollama:/,/^  [a-z]/s/^  /  #/' docker-compose.yml
            
            # Fix any syntax issues caused by commenting
            sed -i 's/^  #}/  #  }/' docker-compose.yml
            
            # Update WebUI to point to host Ollama
            local host_ip=$(hostname -I | awk '{print $1}')
            sed -i "s|OLLAMA_API_BASE_URL=http://ollama:11434|OLLAMA_API_BASE_URL=http://${host_ip}:11434|" docker-compose.yml
            
            # Remove dependencies on ollama service
            sed -i '/depends_on:/,/condition: service_healthy/{/ollama:/,/condition: service_healthy/d;}' docker-compose.yml
            
            log "success" "Updated docker-compose.yml to use host Ollama"
            log "info" "WebUI will connect to Ollama at: http://${host_ip}:11434"
        fi
        
        # Test connection to host Ollama
        log "info" "Testing connection to host Ollama..."
        if curl -s http://localhost:11434/api/tags >/dev/null; then
            log "success" "Successfully connected to host Ollama"
        else
            log "error" "Could not connect to host Ollama. Please ensure it's running and accessible."
            log "info" "You may need to start it with: sudo systemctl start ollama"
        fi
    fi
    
    # Source the updated .env file
    source .env
}

# Function to test Ollama endpoint
test_ollama_endpoint() {
    local url=$1
    local max_attempts=${2:-1}
    local wait_time=${3:-5}
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$url/api/version" | grep -q "200"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            sleep $wait_time
        fi
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Function to test endpoints
test_endpoints() {
    log "info" "Testing endpoints..."
    
    # Test local endpoints
    log "info" "Testing local Ollama endpoint..."
    if test_ollama_endpoint "http://api.localhost" 1 1; then
        log "success" "Local Ollama endpoint is accessible"
    else
        log "error" "Local Ollama endpoint is not accessible"
    fi
    
    if test_ollama_endpoint "http://api.lan" 1 1; then
        log "success" "LAN Ollama endpoint is accessible"
    else
        log "error" "LAN Ollama endpoint is not accessible"
    fi
    
    # Test remote endpoint with retry for DNS propagation
    log "info" "Testing remote Ollama endpoint (waiting for DNS propagation)..."
    if test_ollama_endpoint "https://api.${DOMAIN}" 2 5; then
        log "success" "Remote Ollama endpoint is accessible"
    else
        log "error" "Remote Ollama endpoint is not accessible after 60 seconds"
    fi
}

# Function to pull Docker images with better error handling
pull_docker_images() {
    log "info" "Pulling Docker images (this will get the latest stable versions)..."
    if ! docker-compose pull --include-deps; then
        log "error" "Failed to pull Docker images"
        exit 1
    fi
}

# Function to check network setup
setup_network() {
    # Check if network exists
    log "info" "Checking network setup..."
    if docker network ls | grep -q llm_network; then
        log "info" "Network llm_network already exists"
        
        # Check if network has active endpoints
        if docker network inspect llm_network | grep -q "Containers\":{}" || docker network inspect llm_network | grep -q "\"Containers\": {}"; then
            # Network has no containers, safe to remove and recreate
            log "info" "Removing existing llm_network..."
            docker network rm llm_network || true
            
            # Create the network
            log "info" "Creating llm_network..."
            docker network create --driver bridge llm_network || log "warn" "Could not create llm_network"
        else
            # Network has active containers, reuse it
            log "info" "Network llm_network has active containers, reusing existing network"
        fi
    else
        # Network doesn't exist, create it
        log "info" "Creating llm_network..."
        docker network create --driver bridge llm_network || log "warn" "Could not create llm_network"
    fi

    log "info" "Network preparation complete"
}

# Function to check for and handle orphaned containers
check_orphaned_containers() {
    log "info" "Checking for orphaned containers using llm_network..."
    
    # Get list of all containers connected to llm_network
    local connected_containers=$(docker network inspect llm_network 2>/dev/null | grep -A 5 "Containers" | grep "Name" | awk -F'"' '{print $4}' || echo "")
    
    if [ -n "$connected_containers" ]; then
        log "warn" "Found containers still connected to llm_network:"
        echo "$connected_containers"
        
        # Automatically disconnect containers without prompting
        for container in $connected_containers; do
            log "info" "Disconnecting $container from llm_network..."
            docker network disconnect -f llm_network "$container" || log "warn" "Could not disconnect $container from llm_network"
        done
        log "success" "Disconnected all containers from llm_network"
    else
        log "info" "No orphaned containers found connected to llm_network"
    fi
}

# Improved function to clean up existing containers
cleanup_existing_containers() {
    log "info" "Checking for existing containers..."
    
    # Get list of all containers related to our project
    local containers=$(docker ps -a --filter "label=com.docker.compose.project=llm-docker" --format "{{.Names}}")
    
    if [ -n "$containers" ]; then
        log "info" "Found existing containers, stopping and removing them..."
        
        # Stop and remove containers
        docker-compose down --remove-orphans --volumes
        
        # Double-check if any containers are still running
        local remaining=$(docker ps -a --filter "label=com.docker.compose.project=llm-docker" --format "{{.Names}}")
        if [ -n "$remaining" ]; then
            log "warn" "Some containers could not be removed automatically, forcing removal..."
            echo "$remaining" | xargs docker rm -f
        fi
        
        log "success" "All existing containers have been removed"
    else
        log "info" "No existing containers found"
    fi
    
    # Also check for any stale networks
    local networks=$(docker network ls --filter "label=com.docker.compose.project=llm-docker" --format "{{.Name}}")
    if [ -n "$networks" ]; then
        log "info" "Checking for stale networks..."
        
        for network in $networks; do
            # Check if network has active endpoints
            if docker network inspect "$network" | grep -q "Containers\":{}" || docker network inspect "$network" | grep -q "\"Containers\": {}"; then
                # Network has no containers, safe to remove
                log "info" "Removing stale network: $network"
                docker network rm "$network" || log "warn" "Could not remove network: $network"
            else
                # Network has active containers
                log "warn" "Network $network has active containers and cannot be removed"
                log "info" "You may need to manually disconnect containers from this network later"
            fi
        done
    fi
}

# Function to update /etc/hosts file for local domain resolution
update_hosts_file() {
    log "info" "Checking /etc/hosts file for local domain entries..."
    
    # Define all the domains we need
    local domains=("chat.localhost" "api.localhost" "pad.localhost" "traefik.localhost" 
                  "metrics.localhost" "grafana.localhost" "logs.localhost" "auth.localhost" 
                  "n8n.localhost" "status.localhost" "vault.localhost" "matrix.localhost" 
                  "remote.localhost" "sync.localhost" "notes.localhost" "s3.localhost" 
                  "s3-console.localhost" "files.localhost" "home.localhost" "huginn.localhost")
    
    # Check if all domains are in /etc/hosts
    local missing_domains=()
    for domain in "${domains[@]}"; do
        if ! grep -q "$domain" /etc/hosts; then
            missing_domains+=("$domain")
        fi
    done
    
    # If there are missing domains, try to add them
    if [ ${#missing_domains[@]} -gt 0 ]; then
        log "info" "Some localhost domains are missing from /etc/hosts"
        
        if [ "$OS" = "LINUX" ] || [ "$OS" = "MAC" ]; then
            # Try to update the hosts file with sudo
            if [ -w "/etc/hosts" ]; then
                log "info" "Adding missing domains to /etc/hosts..."
                # Add each domain on a separate line to avoid long lines
                for domain in "${missing_domains[@]}"; do
                    echo "127.0.0.1 $domain" >> /etc/hosts
                done
                log "success" "Updated /etc/hosts file"
            else
                log "warn" "Cannot write to /etc/hosts, attempting with sudo..."
                if command -v sudo &> /dev/null; then
                    if sudo -n true 2>/dev/null; then
                        # We have passwordless sudo
                        for domain in "${missing_domains[@]}"; do
                            echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts > /dev/null
                        done
                        log "success" "Updated /etc/hosts file with sudo"
                    else
                        log "warn" "Sudo requires password, please run the following commands manually:"
                        for domain in "${missing_domains[@]}"; do
                            echo "sudo sh -c 'echo \"127.0.0.1 $domain\" >> /etc/hosts'"
                        done
                    fi
                else
                    log "warn" "Sudo not available, please manually update /etc/hosts"
                    for domain in "${missing_domains[@]}"; do
                        echo "Add this line to /etc/hosts: 127.0.0.1 $domain"
                    done
                fi
            fi
        elif [ "$OS" = "WSL" ]; then
            log "warn" "Running in WSL, please update your Windows hosts file manually"
            for domain in "${missing_domains[@]}"; do
                echo "Add this line to C:\\Windows\\System32\\drivers\\etc\\hosts: 127.0.0.1 $domain"
            done
        fi
    else
        log "success" "All localhost domains are already in /etc/hosts"
    fi
}

# Function to check Docker health
check_docker_health() {
    log "info" "Checking Docker health..."
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log "error" "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check Docker disk space
    local disk_usage=$(docker system df --format "{{.TotalReclaimable}}" 2>/dev/null || echo "N/A")
    if [[ "$disk_usage" != "N/A" && "$disk_usage" != *"0B"* ]]; then
        log "warn" "Docker has reclaimable disk space: $disk_usage"
        log "info" "Consider running 'docker system prune' to free up space"
    fi
    
    # Check for any containers in unhealthy state
    local unhealthy_containers=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null)
    if [ -n "$unhealthy_containers" ]; then
        log "warn" "Found unhealthy containers that might cause issues:"
        echo "$unhealthy_containers"
        log "info" "Consider restarting or removing these containers"
    fi
    
    log "success" "Docker appears to be healthy"
}

# Function to check requirements
check_requirements() {
    log "info" "Checking requirements..."
    
    # Check for required commands
    check_command "docker"
    check_command "docker-compose"
    check_command "htpasswd"
    check_command "aws"
    check_command "lsof"
    
    # Check Docker health
    check_docker_health
    
    # Check current directory permissions
    if [ ! -w "$(pwd)" ]; then
        log "error" "Current directory is not writable: $(pwd)"
        exit 1
    fi
}

# Function to load environment variables from .env file
load_env() {
    log "info" "Loading environment variables..."
    
    if [ -f .env ]; then
        source .env
        log "success" "Loaded environment variables from .env file"
    else
        log "warn" "No .env file found, using default values"
    fi
    
    # Set default values for required variables if not set
    DOMAIN_BASE="${DOMAIN_BASE:-local}"
    DATA_DIR="${DATA_DIR:-/mnt/data}"
    OLLAMA_PORT="${OLLAMA_PORT:-11434}"
    RUSTPAD_PORT="${RUSTPAD_PORT:-3030}"
    
    # Export variables for use in subprocesses
    export DOMAIN_BASE DATA_DIR OLLAMA_PORT RUSTPAD_PORT
}

# Function to check for required variables
check_required_variables() {
    log "info" "Checking required variables..."
    
    # Check if DOMAIN is set when not in local mode
    if [ "${DEPLOYMENT_MODE:-local}" != "local" ] && [ -z "${DOMAIN:-}" ]; then
        log "error" "DOMAIN variable is required for non-local deployments"
        log "info" "Please set DOMAIN in your .env file"
        exit 1
    fi
    
    # Check if ZONE_ID is set when not in local mode
    if [ "${DEPLOYMENT_MODE:-local}" != "local" ] && [ -z "${ZONE_ID:-}" ]; then
        log "warn" "ZONE_ID not set, attempting to retrieve from AWS..."
        ZONE_ID=$(aws_cmd route53 list-hosted-zones-by-name --dns-name "${DOMAIN}." --max-items 1 --query 'HostedZones[0].Id' --output text 2>/dev/null)
        if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "None" ]; then
            log "error" "Could not find Route53 zone ID for ${DOMAIN}"
            log "info" "Please set ZONE_ID in your .env file"
            exit 1
        fi
        ZONE_ID=${ZONE_ID#/hostedzone/}
        log "success" "Retrieved ZONE_ID: ${ZONE_ID}"
        # Add to .env
        if ! grep -q "^ZONE_ID=" .env; then
            echo "ZONE_ID=${ZONE_ID}" >> .env
        else
            sed -i "s/^ZONE_ID=.*/ZONE_ID=${ZONE_ID}/" .env
        fi
    fi
    
    log "success" "All required variables are set"
}

# Function to clean up .env file (remove duplicates)
cleanup_env_file() {
    log "info" "Cleaning up .env file..."
    
    if [ ! -f .env ]; then
        log "warn" "No .env file found, skipping cleanup"
        return
    fi
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Get unique entries preserving order (last occurrence wins)
    awk -F= '!seen[$1]++ {print}' .env > "$temp_file"
    
    # Replace original file
    mv "$temp_file" .env
    
    log "success" "Cleaned up .env file"
}

# Function to check DNS setup
check_dns_setup() {
    log "info" "Checking DNS setup for ${DOMAIN}..."
    
    if [ -z "${ZONE_ID:-}" ]; then
        log "warn" "ZONE_ID is not set, attempting to retrieve from AWS..."
        ZONE_ID=$(aws_cmd route53 list-hosted-zones-by-name --dns-name "${DOMAIN}." --max-items 1 --query 'HostedZones[0].Id' --output text 2>/dev/null)
        if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "None" ]; then
            log "warn" "Could not find Route53 zone ID for ${DOMAIN}, skipping DNS setup"
            return 0
        fi
        ZONE_ID=${ZONE_ID#/hostedzone/}
        log "success" "Retrieved ZONE_ID: ${ZONE_ID}"
        
        # Add to .env file
        if [ -f .env ]; then
            if grep -q "^ZONE_ID=" .env; then
                sed -i "s/^ZONE_ID=.*/ZONE_ID=${ZONE_ID}/" .env
            else
                echo "ZONE_ID=${ZONE_ID}" >> .env
            fi
        else
            echo "ZONE_ID=${ZONE_ID}" > .env
        fi
    fi
    
    # Get current public IP
    local ip_address
    ip_address=$(curl -s --max-time 5 https://api.ipify.org)
    if [[ ! $ip_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "warn" "Failed to get valid public IP address, skipping DNS setup"
        return 0
    fi
    
    log "info" "Current public IP: ${ip_address}"
    
    # List of subdomains to check/create
    local subdomains=("api" "chat" "traefik" "pad" "metrics" "grafana" "logs" "auth" "n8n" "status" "vault" "matrix" "remote" "sync" "notes" "db" "vector" "s3" "s3-console" "files" "home" "huginn")
    
    for subdomain in "${subdomains[@]}"; do
        local record_name="${subdomain}.${DOMAIN}"
        [[ "${record_name}" != *"." ]] && record_name="${record_name}."
        
        log "info" "Checking DNS record for ${record_name}..."
        
        # Check if record exists with timeout
        local existing_record
        existing_record=$(timeout 5 aws_cmd route53 list-resource-record-sets \
            --hosted-zone-id "$ZONE_ID" \
            --query "ResourceRecordSets[?Name=='${record_name}' && Type=='A'].ResourceRecords[0].Value" \
            --output text 2>/dev/null || echo "")
        
        if [ "$existing_record" == "None" ] || [ -z "$existing_record" ]; then
            log "info" "Creating DNS record for ${record_name}..."
            
            # Create record using AWS CLI with proper JSON formatting
            local change_batch=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "CREATE",
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
            
            if ! timeout 10 aws_cmd route53 change-resource-record-sets \
                --hosted-zone-id "$ZONE_ID" \
                --change-batch "$change_batch" >/dev/null 2>&1; then
                log "warn" "Failed to create DNS record for ${record_name}, continuing anyway"
                continue
            fi
            
            log "success" "Created DNS record for ${record_name} pointing to ${ip_address}"
        elif [ "$existing_record" != "$ip_address" ]; then
            log "info" "Updating DNS record for ${record_name} from ${existing_record} to ${ip_address}..."
            
            # Update record using AWS CLI with proper JSON formatting
            local change_batch=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
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
            
            if ! timeout 10 aws_cmd route53 change-resource-record-sets \
                --hosted-zone-id "$ZONE_ID" \
                --change-batch "$change_batch" >/dev/null 2>&1; then
                log "warn" "Failed to update DNS record for ${record_name}, continuing anyway"
                continue
            fi
            
            log "success" "Updated DNS record for ${record_name} to ${ip_address}"
        else
            log "success" "DNS record for ${record_name} already points to ${ip_address}"
        fi
    done
    
    log "info" "DNS setup complete. Note that DNS propagation may take up to 24 hours."
}

# Function to start services
start_services() {
    log "info" "Starting services..."
    
    # Check if we're adding new services to an existing deployment
    local existing_containers=$(docker ps -q --filter "label=com.docker.compose.project=llm-docker")
    local is_update=false
    
    if [ -n "$existing_containers" ]; then
        log "info" "Detected existing containers, performing incremental update"
        is_update=true
    fi
    
    if [ "$is_update" = true ]; then
        # For updates, use docker-compose's idempotent behavior
        # First, stop any conflicting containers that aren't managed by docker-compose
        log "info" "Checking for container name conflicts..."
        
        # Get list of services from docker-compose.yml
        local services=$(docker-compose config --services)
        
        for service in $services; do
            local container_name="${service}-${DOMAIN_BASE}"
            
            # Check if container exists but is not managed by our docker-compose project
            if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
                local label=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$container_name" 2>/dev/null || echo "")
                
                if [ "$label" != "llm-docker" ]; then
                    log "warn" "Found conflicting container: ${container_name}"
                    log "info" "Stopping and renaming conflicting container to allow our service to start"
                    
                    # Stop the container if it's running
                    docker stop "$container_name" 2>/dev/null || true
                    
                    # Rename the container to avoid conflicts
                    local timestamp=$(date +%s)
                    docker rename "$container_name" "${container_name}-old-${timestamp}" 2>/dev/null || true
                    
                    log "success" "Renamed conflicting container ${container_name} to ${container_name}-old-${timestamp}"
                fi
            fi
        done
        
        # Stop and remove existing containers to avoid ContainerConfig KeyError with older docker-compose
        log "info" "Stopping and removing existing containers to avoid recreation issues"
        docker-compose down --remove-orphans || true
        
        # Now start all services fresh
        log "info" "Running incremental update with docker-compose up -d"
        docker-compose up -d
    else
        # For fresh installs, start database services first
        log "info" "Fresh installation detected, starting database services first"
        docker-compose up -d neon-postgres redis
        
        # Wait for database services to be healthy
        wait_for_service_health "neon-postgres-${DOMAIN_BASE}"
        wait_for_service_health "redis-${DOMAIN_BASE}"
        
        # Initialize databases
        initialize_databases
        
        # Start the rest of the services
        log "info" "Starting remaining services"
        docker-compose up -d
    fi
    
    # Wait for services to stabilize
    wait_for_services
    
    log "success" "Services started successfully"
    
    # Display service URLs
    log "info" "Service URLs:"
    if [ -n "${DOMAIN:-}" ]; then
        log "info" "Traefik Dashboard: https://traefik.${DOMAIN}"
        log "info" "Ollama API: https://api.${DOMAIN}"
        log "info" "WebUI: https://chat.${DOMAIN}"
        log "info" "Rustpad: https://pad.${DOMAIN}"
        log "info" "Home Assistant: https://home.${DOMAIN}"
        log "info" "Huginn: https://huginn.${DOMAIN}"
    else
        log "info" "Traefik Dashboard: http://traefik.localhost"
        log "info" "Ollama API: http://api.localhost"
        log "info" "WebUI: http://chat.localhost"
        log "info" "Rustpad: http://pad.localhost"
        log "info" "Home Assistant: http://home.localhost"
        log "info" "Huginn: http://huginn.localhost"
    fi
}

# Function to update docker-compose.yml for compatibility with current Docker version
update_docker_compose_compatibility() {
    log "info" "Checking Docker version for compatibility..."
    
    # Get Docker version
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || docker version | grep 'Version:' | head -n 1 | awk '{print $2}')
    
    if [ -z "$docker_version" ]; then
        log "warn" "Could not determine Docker version, skipping compatibility check"
        return
    fi
    
    log "info" "Detected Docker version: ${docker_version}"
    
    # Check if version is >= 20.10.0 (which supports depends_on conditions)
    local major_version minor_version
    major_version=$(echo "$docker_version" | cut -d. -f1)
    minor_version=$(echo "$docker_version" | cut -d. -f2)
    
    if [ "$major_version" -lt 20 ] || ([ "$major_version" -eq 20 ] && [ "$minor_version" -lt 10 ]); then
        log "warn" "Docker version ${docker_version} may not support depends_on conditions"
        log "info" "Updating docker-compose.yml for compatibility..."
        
        # Create a backup if it doesn't exist
        if [ ! -f docker-compose.yml.original ]; then
            cp docker-compose.yml docker-compose.yml.original
        fi
        
        # Remove condition from depends_on
        sed -i.bak -E 's/condition: service_healthy//g' docker-compose.yml
        sed -i.bak -E 's/depends_on:[[:space:]]*\{\}/depends_on: []/' docker-compose.yml
        
        # Clean up backup files
        rm -f docker-compose.yml.bak
        
        log "success" "Updated docker-compose.yml for compatibility with Docker ${docker_version}"
    else
        log "success" "Docker version ${docker_version} supports all features in docker-compose.yml"
    fi
}

# Function to update the check_docker_images function to provide better messages
check_docker_images() {
    local service=$1
    local image_exists
    
    # Skip checking for ollama if it's running as a system service
    if [[ "$service" == "ollama" && -n "${OLLAMA_SYSTEM_SERVICE:-}" ]]; then
        log "info" "Skipping Ollama image pull as it's running as a system service"
        return 0
    fi
    
    # Skip checking for neon as we're using neon-postgres instead
    if [[ "$service" == "neon" ]]; then
        log "info" "Skipping neon image pull as we're using neon-postgres instead"
        return 0
    fi
    
    image_exists=$(docker-compose config --services | grep -w "$service" || true)
    
    if [[ -z "$image_exists" ]]; then
        log "warning" "Service $service not found in docker-compose.yml"
        return 1
    fi
    
    if docker-compose pull --include-deps "$service" &>/dev/null; then
        log "success" "Successfully pulled image for $service"
        return 0
    else
        log "error" "Failed to pull image for $service"
        log "info" "This service will be skipped during startup. Check image name and version."
        return 1
    fi
}

# Update the initialize_databases function to include all services
initialize_databases() {
    log "info" "Initializing databases for services..."
    
    # Create database for Postiz if it doesn't exist
    if ! docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw postiz; then
        log "info" "Creating database for Postiz..."
        docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -c "CREATE DATABASE postiz;"
        log "success" "Database for Postiz created successfully"
    else
        log "info" "Database for Postiz already exists"
    fi
    
    # Create database for OpenWebUI if it doesn't exist
    if ! docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw openwebui; then
        log "info" "Creating database for OpenWebUI..."
        docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -c "CREATE DATABASE openwebui;"
        log "success" "Database for OpenWebUI created successfully"
    else
        log "info" "Database for OpenWebUI already exists"
    fi
    
    # Create database for Coolify if it doesn't exist
    if ! docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw coolify; then
        log "info" "Creating database for Coolify..."
        docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -c "CREATE DATABASE coolify;"
        log "success" "Database for Coolify created successfully"
    else
        log "info" "Database for Coolify already exists"
    fi
    
    # Create database for n8n if it doesn't exist
    if ! docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw n8n; then
        log "info" "Creating database for n8n..."
        docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -c "CREATE DATABASE n8n;"
        log "success" "Database for n8n created successfully"
    else
        log "info" "Database for n8n already exists"
    fi
    
    # Create database for Vaultwarden if it doesn't exist
    if ! docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw vaultwarden; then
        log "info" "Creating database for Vaultwarden..."
        docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -c "CREATE DATABASE vaultwarden;"
        log "success" "Database for Vaultwarden created successfully"
    else
        log "info" "Database for Vaultwarden already exists"
    fi
    
    # Create database for Authelia if it doesn't exist
    if ! docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw authelia; then
        log "info" "Creating database for Authelia..."
        docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -c "CREATE DATABASE authelia;"
        log "success" "Database for Authelia created successfully"
    else
        log "info" "Database for Authelia already exists"
    fi
    
    # Create database for Grafana if it doesn't exist
    if ! docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw grafana; then
        log "info" "Creating database for Grafana..."
        docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -c "CREATE DATABASE grafana;"
        log "success" "Database for Grafana created successfully"
    else
        log "info" "Database for Grafana already exists"
    fi
    
    # Create database for Uptime Kuma if it doesn't exist
    if ! docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw uptimekuma; then
        log "info" "Creating database for Uptime Kuma..."
        docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -c "CREATE DATABASE uptimekuma;"
        log "success" "Database for Uptime Kuma created successfully"
    else
        log "info" "Database for Uptime Kuma already exists"
    fi
    
    # Create database for Huginn if it doesn't exist
    if ! docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -lqt | cut -d \| -f 1 | grep -qw huginn; then
        log "info" "Creating database for Huginn..."
        docker exec neon-postgres-${DOMAIN_BASE} psql -U postgres -c "CREATE DATABASE huginn;"
        log "success" "Database for Huginn created successfully"
    else
        log "info" "Database for Huginn already exists"
    fi
}

# Add this function before it's called in the script (around line 940)
wait_for_service_health() {
    local service=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    log "info" "Waiting for $service to be healthy..."
    
    while [ $attempt -le $max_attempts ]; do
        if docker ps --filter "name=$service" --filter "health=healthy" --format "{{.Names}}" | grep -q "$service"; then
            log "success" "$service is healthy"
            return 0
        fi
        
        log "info" "Waiting for $service to be healthy (attempt $attempt/$max_attempts)..."
        sleep 5
        ((attempt++))
    done
    
    log "error" "Timed out waiting for $service to be healthy"
    return 1
}

# Add this function after the wait_for_service_health function
ensure_coolify_directory() {
    local coolify_dir="${DATA_DIR:-/mnt/data}/coolify"
    
    if [ ! -d "$coolify_dir" ]; then
        log "info" "Creating Coolify directory: $coolify_dir"
        mkdir -p "$coolify_dir"
        chmod 755 "$coolify_dir"
        log "success" "Coolify directory created successfully"
    else
        log "info" "Coolify directory already exists"
    fi
}

# Function to check service logs for errors
check_service_logs() {
    local service=$1
    local container_name="${service}-${DOMAIN_BASE}"
    
    log "info" "Checking logs for $container_name..."
    
    # Get the last 20 lines of logs
    local logs=$(docker logs --tail 20 "$container_name" 2>&1)
    
    # Check for common error patterns
    if echo "$logs" | grep -q "permission denied"; then
        log "error" "Permission issues detected for $service"
        log "info" "Try: sudo chown -R $(whoami):$(whoami) ${DATA_DIR:-/mnt/data}/$service"
    elif echo "$logs" | grep -q "connection refused"; then
        log "error" "Connection issues detected for $service"
        log "info" "Check if dependent services are running properly"
    elif echo "$logs" | grep -q "out of memory"; then
        log "error" "Memory issues detected for $service"
        log "info" "Consider increasing memory limits in docker-compose.yml"
    fi
    
    # Return success to continue with other services
    return 0
}

# Function to wait for services with better error handling
wait_for_services() {
    log "info" "Waiting for services to stabilize..."
    
    # List of services to check
    local services=("neon-postgres" "redis" "vector" "webui" "authelia" "conduit" "spacedrive" "homeassistant" "huginn")
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        local all_stable=true
        
        for service in "${services[@]}"; do
            local container_name="${service}-${DOMAIN_BASE}"
            local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found")
            local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || echo "not_found")
            local restarts=$(docker inspect --format='{{.RestartCount}}' "$container_name" 2>/dev/null || echo "0")
            
            if [ "$status" != "running" ] || ([ "$health" != "none" ] && [ "$health" != "healthy" ]) || [ "$restarts" -gt 2 ]; then
                all_stable=false
                log "warn" "$container_name is not stable (status: $status, health: $health, restarts: $restarts)"
                check_service_logs "$service"
            fi
        done
        
        if $all_stable; then
            log "success" "All services are stable"
            return 0
        fi
        
        log "info" "Waiting for services to stabilize (attempt $(($retry + 1))/$max_retries)..."
        sleep 30
        ((retry++))
    done
    
    log "warn" "Some services are still not stable after $max_retries attempts"
    log "info" "You may need to check logs with: docker logs <container-name>"
    return 1
}

# Function to prompt for AWS profile
prompt_for_aws_profile() {
    log "info" "Checking AWS profile settings..."

    # Check if AWS_PROFILE is already set (which happens when leo alias is run)
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        log "info" "AWS profile is already set to ${AWS_PROFILE}"
        # Verify AWS credentials
        if aws_cmd sts get-caller-identity &>/dev/null; then
            log "success" "AWS credentials verified successfully"
            return 0
        else
            log "error" "AWS credentials verification failed with profile ${AWS_PROFILE}. Continuing with manual profile selection."
        fi
    else
        log "warn" "AWS_PROFILE is not set. If you have an AWS profile alias (like 'leo'), please run it before executing this script."
    fi

    # Continue with existing profile selection code
    # Check for AWS profile functions in zshrc
    local zshrc_path="${ZDOTDIR:-$HOME}/.zshrc"
    local profile_functions=()

    # Extract AWS profile function aliases from zshrc
    if [ -f "$zshrc_path" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*alias[[:space:]]+([a-zA-Z0-9_-]+)[[:space:]]*=.*AWS_PROFILE.*$ ]]; then
                profile_functions+=("${BASH_REMATCH[1]}")
            fi
        done < "$zshrc_path"
    fi

    # Get available AWS profiles
    local available_profiles=$(aws_cmd configure list-profiles 2>/dev/null)
    if [ -z "$available_profiles" ]; then
        log "warn" "No AWS profiles found. Please configure AWS CLI first."
        return 1
    fi

    # Convert available profiles to array
    readarray -t profile_list <<< "$available_profiles"

    # Add the leo function as an option
    profile_list+=("Use leo function")
    
    # Check if AWS_PROFILE is already set
    local current_profile="${AWS_PROFILE:-}"
    
    # Check if AWS_PROFILE is in .env file
    if [ -z "$current_profile" ] && [ -f .env ] && grep -q "^AWS_PROFILE=" .env; then
        current_profile=$(grep "^AWS_PROFILE=" .env | cut -d= -f2)
    fi
    
    # If current_profile is set, find its index in profile_list
    local default_option=1
    if [ -n "$current_profile" ]; then
        for i in "${!profile_list[@]}"; do
            if [ "${profile_list[$i]}" = "$current_profile" ]; then
                default_option=$((i+1))
                break
            fi
        done
    fi
    
    # If there are only profile functions, just use them
    if [ ${#profile_list[@]} -eq 0 ] && [ ${#profile_functions[@]} -gt 0 ]; then
        log "info" "Available AWS profile functions from your zshrc:"
        for i in "${!profile_functions[@]}"; do
            log "info" "f$((i+1))) ${profile_functions[$i]}"
        done
        
        local choice
        read -p "Select AWS profile function [f1-f${#profile_functions[@]}]: " choice
        
        if [[ "$choice" =~ ^f([0-9]+)$ ]]; then
            local index=$((${BASH_REMATCH[1]}-1))
            if [ "$index" -ge 0 ] && [ "$index" -lt ${#profile_functions[@]} ]; then
                local selected_function="${profile_functions[$index]}"
                log "info" "Running AWS profile function: $selected_function"
                
                # Try to extract AWS_PROFILE from the function definition
                local func_def=$(grep -A 10 "alias $selected_function=" "$zshrc_path" | grep -m 1 "export AWS_PROFILE=" | sed 's/.*export AWS_PROFILE=\([^ ]*\).*/\1/')
                
                if [ -n "$func_def" ]; then
                    export AWS_PROFILE="$func_def"
                    log "success" "Set AWS_PROFILE to $AWS_PROFILE from function $selected_function"
                    
                    # Save AWS_PROFILE to .env
                    if [ -f .env ]; then
                        if grep -q "^AWS_PROFILE=" .env; then
                            sed -i "s/^AWS_PROFILE=.*/AWS_PROFILE=$AWS_PROFILE/" .env
                        else
                            echo "AWS_PROFILE=$AWS_PROFILE" >> .env
                        fi
                    else
                        echo "AWS_PROFILE=$AWS_PROFILE" > .env
                    fi
                    
                    # Verify AWS credentials
                    if ! aws_cmd sts get-caller-identity &>/dev/null; then
                        log "error" "AWS credentials verification failed. Please check your AWS profile."
                        return 1
                    fi
                    
                    log "success" "AWS credentials verified successfully"
                    return 0
                else
                    log "error" "Could not extract AWS_PROFILE from function $selected_function"
                    return 1
                fi
            fi
        fi
        
        log "error" "Invalid selection"
        return 1
    fi

    # If there are both profile functions and regular profiles
    local choice
    if [ ${#profile_list[@]} -gt 0 ] && [ ${#profile_functions[@]} -gt 0 ]; then
        log "info" "Available AWS profiles:"
        for i in "${!profile_list[@]}"; do
            log "info" "$((i+1))) ${profile_list[$i]}"
        done
        
        log "info" "Available AWS profile functions from your zshrc:"
        for i in "${!profile_functions[@]}"; do
            log "info" "f$((i+1))) ${profile_functions[$i]}"
        done
        
        # If there's a current profile, set it as default
        if [ -n "$current_profile" ]; then
            read -p "Select AWS profile [default: $default_option - ${profile_list[$((default_option-1))]}]: " choice
            if [ -z "$choice" ]; then
                choice=$default_option
            fi
        else
            read -p "Select AWS profile [1-${#profile_list[@]}] or function [f1-f${#profile_functions[@]}]: " choice
        fi
        
        # Process choice
        if [[ "$choice" =~ ^f([0-9]+)$ ]]; then
            local index=$((${BASH_REMATCH[1]}-1))
            if [ "$index" -ge 0 ] && [ "$index" -lt ${#profile_functions[@]} ]; then
                local selected_function="${profile_functions[$index]}"
                log "info" "Running AWS profile function: $selected_function"
                
                # Try to extract AWS_PROFILE from the function definition
                local func_def=$(grep -A 10 "alias $selected_function=" "$zshrc_path" | grep -m 1 "export AWS_PROFILE=" | sed 's/.*export AWS_PROFILE=\([^ ]*\).*/\1/')
                
                if [ -n "$func_def" ]; then
                    export AWS_PROFILE="$func_def"
                    log "success" "Set AWS_PROFILE to $AWS_PROFILE from function $selected_function"
                    
                    # Save AWS_PROFILE to .env
                    if [ -f .env ]; then
                        if grep -q "^AWS_PROFILE=" .env; then
                            sed -i "s/^AWS_PROFILE=.*/AWS_PROFILE=$AWS_PROFILE/" .env
                        else
                            echo "AWS_PROFILE=$AWS_PROFILE" >> .env
                        fi
                    else
                        echo "AWS_PROFILE=$AWS_PROFILE" > .env
                    fi
                    
                    # Verify AWS credentials
                    if ! aws_cmd sts get-caller-identity &>/dev/null; then
                        log "error" "AWS credentials verification failed. Please check your AWS profile."
                        return 1
                    fi
                    
                    log "success" "AWS credentials verified successfully"
                    return 0
                else
                    log "error" "Could not extract AWS_PROFILE from function $selected_function"
                    return 1
                fi
            fi
        elif [[ "$choice" =~ ^([0-9]+)$ ]] || [ -n "$choice" ]; then
            local index=$((choice-1))
            if [ "$index" -ge 0 ] && [ "$index" -lt ${#profile_list[@]} ]; then
                local selected_profile="${profile_list[$index]}"
                
                # Check if the selected option is the leo function
                if [ "$selected_profile" == "Use leo function" ]; then
                    log "info" "Using leo function for AWS authentication..."
                    if leo; then
                        log "success" "AWS authentication successful using leo function"
                        # Verify AWS credentials
                        if aws_cmd sts get-caller-identity &>/dev/null; then
                            log "success" "AWS credentials verified successfully"
                            return 0
                        else
                            log "error" "AWS credentials verification failed after leo authentication."
                            return 1
                        fi
                    else
                        log "error" "Failed to authenticate using leo function."
                        return 1
                    fi
                fi
                
                # Set the AWS_PROFILE environment variable
                export AWS_PROFILE="$selected_profile"
                
                # Save AWS_PROFILE to .env
                if [ -f .env ]; then
                    if grep -q "^AWS_PROFILE=" .env; then
                        sed -i "s/^AWS_PROFILE=.*/AWS_PROFILE=$selected_profile/" .env
                    else
                        echo "AWS_PROFILE=$selected_profile" >> .env
                    fi
                else
                    echo "AWS_PROFILE=$selected_profile" > .env
                fi
                
                log "success" "Using AWS profile: $selected_profile"
            else
                log "error" "Invalid selection"
                return 1
            fi
        else
            # Try to run the selected function directly
            local selected_profile="$choice"
            if type "$selected_profile" &>/dev/null; then
                if $selected_profile; then
                    log "success" "Successfully activated AWS profile function: $selected_profile"
                else
                    log "warn" "Failed to run AWS profile function: $selected_profile"
                    return 1
                fi
            else
                log "error" "Invalid selection: $selected_profile"
                return 1
            fi
        fi
        
        # Verify AWS credentials
        if ! aws_cmd sts get-caller-identity &>/dev/null; then
            log "error" "AWS credentials verification failed. Please check your AWS profile."
            return 1
        fi
        
        log "success" "AWS credentials verified successfully"
        return 0
    else
        # Only regular profiles are available
        log "info" "Available AWS profiles:"
        for i in "${!profile_list[@]}"; do
            log "info" "$((i+1))) ${profile_list[$i]}"
        done
        
        # If there's a current profile, set it as default
        if [ -n "$current_profile" ]; then
            read -p "Select AWS profile [default: $default_option - ${profile_list[$((default_option-1))]}]: " choice
            if [ -z "$choice" ]; then
                choice=$default_option
            fi
        else
            read -p "Select AWS profile [1-${#profile_list[@]}]: " choice
        fi
        
        if [[ "$choice" =~ ^([0-9]+)$ ]] || [ -n "$choice" ]; then
            local index=$((choice-1))
            if [ "$index" -ge 0 ] && [ "$index" -lt ${#profile_list[@]} ]; then
                local selected_profile="${profile_list[$index]}"
                
                # Check if the selected option is the leo function
                if [ "$selected_profile" == "Use leo function" ]; then
                    log "info" "Using leo function for AWS authentication..."
                    if leo; then
                        log "success" "AWS authentication successful using leo function"
                        # Verify AWS credentials
                        if aws_cmd sts get-caller-identity &>/dev/null; then
                            log "success" "AWS credentials verified successfully"
                            return 0
                        else
                            log "error" "AWS credentials verification failed after leo authentication."
                            return 1
                        fi
                    else
                        log "error" "Failed to authenticate using leo function."
                        return 1
                    fi
                fi
                
                # Set the AWS_PROFILE environment variable
                export AWS_PROFILE="$selected_profile"
                
                # Save AWS_PROFILE to .env
                if [ -f .env ]; then
                    if grep -q "^AWS_PROFILE=" .env; then
                        sed -i "s/^AWS_PROFILE=.*/AWS_PROFILE=$selected_profile/" .env
                    else
                        echo "AWS_PROFILE=$selected_profile" >> .env
                    fi
                else
                    echo "AWS_PROFILE=$selected_profile" > .env
                fi
                
                log "success" "Using AWS profile: $selected_profile"
            else
                log "error" "Invalid selection"
                return 1
            fi
        else
            # Try to run the selected function directly
            local selected_profile="$choice"
            if type "$selected_profile" &>/dev/null; then
                if $selected_profile; then
                    log "success" "Successfully activated AWS profile function: $selected_profile"
                else
                    log "warn" "Failed to run AWS profile function: $selected_profile"
                    return 1
                fi
            else
                log "error" "Invalid selection: $selected_profile"
                return 1
            fi
        fi
        
        # Verify AWS credentials
        if ! aws_cmd sts get-caller-identity &>/dev/null; then
            log "error" "AWS credentials verification failed. Please check your AWS profile."
            return 1
        fi
        
        log "success" "AWS credentials verified successfully"
        return 0
    fi
}

# Function to prompt for domain
prompt_for_domain() {
    log "info" "Checking domain settings..."
    
    # Check if DOMAIN is already set in environment
    local current_domain="${DOMAIN:-}"
    
    # Check if DOMAIN is in .env file
    if [ -z "$current_domain" ] && [ -f .env ] && grep -q "^DOMAIN=" .env; then
        current_domain=$(grep "^DOMAIN=" .env | cut -d= -f2)
    fi
    
    # Prompt for domain with default
    local selected_domain=""
    
    if [ -n "$current_domain" ]; then
        read -p "Enter domain name [default: $current_domain]: " domain_input
        selected_domain=${domain_input:-$current_domain}
    else
        read -p "Enter domain name: " domain_input
        if [ -z "$domain_input" ]; then
            log "error" "Domain name cannot be empty."
            return 1
        fi
        selected_domain="$domain_input"
    fi
    
    # Set the DOMAIN environment variable
    export DOMAIN="$selected_domain"
    
    # Set DOMAIN_BASE
    export DOMAIN_BASE=$(echo "$selected_domain" | sed -E 's/\.[^.]+$//')
    
    # Update .env file
    if [ -f .env ]; then
        if grep -q "^DOMAIN=" .env; then
            sed -i "s/^DOMAIN=.*/DOMAIN=$selected_domain/" .env
        else
            echo "DOMAIN=$selected_domain" >> .env
        fi
        
        if grep -q "^DOMAIN_BASE=" .env; then
            sed -i "s/^DOMAIN_BASE=.*/DOMAIN_BASE=$DOMAIN_BASE/" .env
        else
            echo "DOMAIN_BASE=$DOMAIN_BASE" >> .env
        fi
    else
        echo "DOMAIN=$selected_domain" > .env
        echo "DOMAIN_BASE=$DOMAIN_BASE" >> .env
    fi
    
    log "success" "Using domain: $selected_domain (base: $DOMAIN_BASE)"
    return 0
}

# Function to modify AWS CLI commands to use the selected profile
aws_cmd() {
    if [ -n "${AWS_PROFILE:-}" ]; then
        aws --profile "$AWS_PROFILE" "$@"
    else
        aws "$@"
    fi
}

# Initialize Coolify after it starts
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

# Main function
main() {
    # Check requirements
    check_requirements
    
    # Prompt for AWS profile
    prompt_for_aws_profile
    
    # Prompt for domain
    prompt_for_domain
    
    # Check if .env file exists
    if [ ! -f .env ]; then
        log "info" "Creating .env file from template..."
        cp .env.example .env
        log "success" "Created .env file from template"
    fi
    
    # Load environment variables
    load_env
    
    # Check for required variables
    check_required_variables
    
    # Check if we're adding new services to an existing deployment
    local existing_containers=$(docker ps -q --filter "label=com.docker.compose.project=llm-docker")
    local is_update=false
    
    if [ -n "$existing_containers" ]; then
        log "info" "Detected existing containers, performing incremental update"
        is_update=true
    fi
    
    # Check for orphaned containers
    check_orphaned_containers
    
    # Only clean up existing containers if this is a fresh install
    if [ "$is_update" = false ]; then
        log "info" "Fresh installation detected, cleaning up any stale containers"
        cleanup_existing_containers
    else
        log "info" "Incremental update, preserving existing containers"
    fi
    
    # Create data directories
    create_data_directories
    
    # Clean up .env file (remove duplicates)
    cleanup_env_file
    
    # Update credentials with domain base
    update_env_credentials "$DOMAIN_BASE"
    
    # Set domain base for container names
    if [ -z "${DOMAIN_BASE}" ]; then
        DOMAIN_BASE=$(get_domain_base "${DOMAIN}")
        # Add to .env if not present
        if ! grep -q "^DOMAIN_BASE=" .env; then
            echo "DOMAIN_BASE=${DOMAIN_BASE}" >> .env
        fi
    fi
    export DOMAIN_BASE
    
    # Update hosts file for local domain resolution
    update_hosts_file
    
    # Check DNS setup if domain is provided
    if [ -n "${DOMAIN:-}" ]; then
        # Try to retrieve ZONE_ID from AWS if not set
        if [ -z "${ZONE_ID:-}" ]; then
            log "info" "ZONE_ID not set, attempting to retrieve from AWS..."
            ZONE_ID=$(aws_cmd route53 list-hosted-zones-by-name --dns-name "${DOMAIN}." --max-items 1 --query 'HostedZones[0].Id' --output text 2>/dev/null)
            if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "None" ]; then
                log "warn" "Could not find Route53 zone ID for ${DOMAIN}, skipping DNS setup"
            else
                ZONE_ID=${ZONE_ID#/hostedzone/}
                log "success" "Retrieved ZONE_ID: ${ZONE_ID}"
                # Add to .env
                if ! grep -q "^ZONE_ID=" .env; then
                    echo "ZONE_ID=${ZONE_ID}" >> .env
                else
                    sed -i "s/^ZONE_ID=.*/ZONE_ID=${ZONE_ID}/" .env
                fi
                # Now that we have the ZONE_ID, proceed with DNS setup
                check_dns_setup
            fi
        else
            # ZONE_ID is already set, proceed with DNS setup
            check_dns_setup
        fi
    fi
    
    # Setup network
    setup_network
    
    # Update ports in docker-compose.yml if needed
    if [ -n "${OLLAMA_PORT:-}" ] || [ -n "${RUSTPAD_PORT:-}" ]; then
        log "info" "Updating ports in docker-compose.yml..."
        
        # Create a backup of the original file
        cp docker-compose.yml docker-compose.yml.original
        
        # Update ports in docker-compose.yml
        sed -i.tmp \
            -e "s/\"11434\"/\"$OLLAMA_PORT\"/" \
            -e "s/\"3030\"/\"$RUSTPAD_PORT\"/" \
            docker-compose.yml
        
        rm -f docker-compose.yml.tmp
    fi
    
    # Setup Ollama
    setup_ollama
    
    # Update docker-compose.yml for compatibility with current Docker version
    update_docker_compose_compatibility
    
    # Pull Docker images
    pull_docker_images
    
    # Ensure Coolify directory exists
    ensure_coolify_directory
    
    # Start services
    start_services
    
    # Initialize Coolify
    initialize_coolify
    
    # Test endpoints
    test_endpoints
    
    log "success" "Setup completed successfully!"
}

# Call the main function
main

