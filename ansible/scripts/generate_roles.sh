#!/bin/bash

# Set strict error handling
set -euo pipefail
IFS=$'\n\t'

# Base directories
ROLES_DIR="roles"
TEMPLATE_DIR="roles/service-template"

# Role configurations with metadata
declare -A ROLES_CONFIG=(
    # Core Infrastructure (Low Resource Usage)
    ["traefik"]="reverse proxy and ssl management;low;network"
    ["authelia"]="authentication service;low;security"
    ["wireguard"]="vpn service;low;network"
    ["fail2ban"]="intrusion prevention;low;security"
    ["ufw"]="firewall management;low;security"
    ["iptables_config"]="base firewall rules;low;security"
    ["hickory_dns"]="dns server;low;network"
    
    # Monitoring & Metrics (Medium Resource Usage)
    ["prometheus"]="metrics collection;medium;monitoring"
    ["grafana"]="visualization dashboard;medium;monitoring"
    ["loki"]="log aggregation;medium;monitoring"
    ["node_exporter"]="system metrics;low;monitoring"
    ["uptime_kuma"]="uptime monitoring;low;monitoring"
    
    # Storage & Sync (Storage Dependent)
    ["syncthing"]="file synchronization;medium;storage"
    ["restic"]="backup solution;medium;storage"
    
    # Security & Identity (Medium Resource Usage)
    ["vaultwarden"]="password management;medium;security"
    ["logto"]="identity management;medium;security"
    
    # Media & Gaming (Medium-High Resource Usage)
    ["kodi"]="media center;high;media"
    ["retro_pi"]="retro gaming;medium;media"
    
    # Home Automation (Low-Medium Resource Usage)
    ["home_assistant"]="home automation hub;medium;automation"
    ["homekit_bridge"]="apple homekit bridge;low;automation"
    ["diyhue"]="philips hue emulation;low;automation"
    
    # Communication (Medium Resource Usage)
    ["matrix"]="chat server;medium;communication"
    ["jitsi"]="video conferencing;high;communication"
    ["guacamole"]="remote desktop gateway;medium;communication"
    
    # AI and Automation (High Resource Usage - Alef Only)
    ["librechat"]="chat interface;high;ai"
    ["ollama"]="ai model server;high;ai"
    ["mistral_rs"]="rust inference engine;high;ai"
    ["openwebui"]="ai web interface;medium;ai"
    ["huginn"]="automation agents;medium;automation"
    ["n8n"]="workflow automation;medium;automation"
    ["whodb"]="database service;medium;storage"
    
    # Development (Low-Medium Resource Usage)
    ["rustdesk"]="remote desktop;medium;development"
    ["rustpad"]="collaborative editor;low;development"
    ["coolify"]="self hosting platform;medium;development"
    ["postiz"]="documentation system;low;development"
    
    # System Management (Low Resource Usage)
    ["cockpit"]="system management;low;system"
)

# Function to parse role metadata
parse_role_metadata() {
    local metadata=$1
    local IFS=";"
    read -r description resource_usage category <<< "$metadata"
    echo "Description: $description"
    echo "Resource Usage: $resource_usage"
    echo "Category: $category"
}

# Function to create role directory structure
create_role_structure() {
    local role=$1
    local metadata=$2
    local role_dir="${ROLES_DIR}/${role//-/_}"
    
    # Parse metadata
    local description resource_usage category
    IFS=";" read -r description resource_usage category <<< "$metadata"
    
    echo "Generating role: $role"
    
    # Create role directory if it doesn't exist
    if [[ ! -d "$role_dir" ]]; then
        mkdir -p "$role_dir"/{defaults,handlers,tasks,templates,vars}
        
        # Copy template files
        cp -r "$TEMPLATE_DIR/defaults/main.yml" "$role_dir/defaults/"
        cp -r "$TEMPLATE_DIR/handlers/main.yml" "$role_dir/handlers/"
        cp -r "$TEMPLATE_DIR/tasks/main.yml" "$role_dir/tasks/"
        
        # Update role name and description in defaults/main.yml
        sed -i "s/service_name: myservice/service_name: $role/" "$role_dir/defaults/main.yml"
        sed -i "s/Service Description/$description/" "$role_dir/defaults/main.yml"
        
        # Add resource requirements based on usage level
        case $resource_usage in
            "low")
                sed -i "s/min_ram_mb: 256/min_ram_mb: 256/" "$role_dir/defaults/main.yml"
                sed -i "s/min_cpu_cores: 1/min_cpu_cores: 1/" "$role_dir/defaults/main.yml"
                ;;
            "medium")
                sed -i "s/min_ram_mb: 256/min_ram_mb: 512/" "$role_dir/defaults/main.yml"
                sed -i "s/min_cpu_cores: 1/min_cpu_cores: 2/" "$role_dir/defaults/main.yml"
                ;;
            "high")
                sed -i "s/min_ram_mb: 256/min_ram_mb: 1024/" "$role_dir/defaults/main.yml"
                sed -i "s/min_cpu_cores: 1/min_cpu_cores: 4/" "$role_dir/defaults/main.yml"
                ;;
        esac
        
        # Create README.md with role information
        cat > "$role_dir/README.md" << EOF
# Ansible Role: $role

## Description
$description

## Category
$category

## Resource Requirements
- Minimum RAM: \$(grep min_ram_mb "$role_dir/defaults/main.yml" | cut -d: -f2)MB
- Minimum CPU Cores: \$(grep min_cpu_cores "$role_dir/defaults/main.yml" | cut -d: -f2)

## Requirements
- Ansible 2.10 or higher
- Linux host

## Role Variables
See \`defaults/main.yml\` for all variables and their default values.

## Dependencies
None.

## Example Playbook
\`\`\`yaml
- hosts: servers
  roles:
    - role: $role
\`\`\`

## Verification
This role includes built-in verification steps that run automatically during deployment:
- System requirements check
- Package installation verification
- Service status verification
- Configuration validation
- Port availability check (if applicable)
- Health endpoint check (if enabled)
- Backup configuration verification (if enabled)

## License
MIT

## Author Information
Created for Homelab deployment
EOF

        # Create empty config template
        touch "$role_dir/templates/config.yml.j2"
        
    else
        echo "Role directory already exists: $role_dir"
    fi
}

# Main execution
main() {
    # Ensure base directories exist
    mkdir -p "$ROLES_DIR"
    
    # Generate roles
    for role in "${!ROLES_CONFIG[@]}"; do
        create_role_structure "$role" "${ROLES_CONFIG[$role]}"
    done
    
    echo "Role generation complete"
}

main
