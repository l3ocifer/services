#!/bin/bash
# Cloudflare DNS Record Management for leopaska.xyz
# Ensures all subdomains point to the Cloudflare Tunnel

set -e

# Cloudflare configuration
ZONE_ID="7ec42a804e4137fa29452223b5f82d26"
TOKEN="${CLOUDFLARE_API_TOKEN:-0PfZeGeX-q-xb5BMl2WKeqTUV-37E2G6dFHtNdfS}"
TUNNEL_ID="8a8129e7-f8c3-4cc4-8b1f-9995da97fff0"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$TOKEN" ]; then
    echo -e "${RED}Error: CLOUDFLARE_API_TOKEN not set${NC}"
    exit 1
fi

# All required subdomains (from config.yml)
SUBDOMAINS=(
    "ae"
    "adminer"
    "argocd"
    "authelia"
    "blink"
    "conduit"
    "coolify"
    "discover"
    "element"
    "grafana"
    "grafana-k3s"
    "homeassistant"
    "huginn"
    "hyva"
    "ipfs"
    "jellyfin"
    "librechat"
    "live"
    "loki"
    "mailhog"
    "minio"
    "n8n"
    "nodeexporter"
    "ollama"
    "omni"
    "openwebui"
    "pgadmin"
    "postiz"
    "potluck"
    "prometheus"
    "prometheus-k3s"
    "rabbitmq"
    "rustdesk"
    "rustpad"
    "spacedrive"
    "syncthing"
    "traefik"
    "traefik-k3s"
    "umami"
    "uptimekuma"
    "ursulai"
    "vaultwarden"
    "whodb"
)

# Function to check if DNS record exists
check_dns_record() {
    local subdomain=$1
    local response=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${subdomain}.leopaska.xyz&type=CNAME" \
        -H "Authorization: Bearer ${TOKEN}")
    
    local count=$(echo "$response" | jq -r '.result | length')
    echo "$count"
}

# Function to create DNS record (CNAME to tunnel)
create_dns_record() {
    local subdomain=$1
    local response=$(curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{
            \"type\": \"CNAME\",
            \"name\": \"${subdomain}\",
            \"content\": \"${TUNNEL_ID}.cfargotunnel.com\",
            \"proxied\": true,
            \"ttl\": 1,
            \"comment\": \"Cloudflare Tunnel for homelab services\"
        }")
    
    local success=$(echo "$response" | jq -r '.success')
    if [ "$success" = "true" ]; then
        echo -e "${GREEN}✓${NC} Created: ${subdomain}.leopaska.xyz"
    else
        local errors=$(echo "$response" | jq -r '.errors[0].message')
        echo -e "${RED}✗${NC} Failed: ${subdomain}.leopaska.xyz - ${errors}"
    fi
}

# Function to list all DNS records
list_dns_records() {
    echo -e "${YELLOW}=== Current DNS Records ===${NC}"
    curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CNAME&per_page=100" \
        -H "Authorization: Bearer ${TOKEN}" | \
        jq -r '.result[]? | "\(.name) → \(.content)"' | \
        grep "leopaska.xyz" | sort || echo "No CNAME records found"
}

# Function to verify token permissions
verify_token() {
    echo -e "${YELLOW}=== Verifying Cloudflare Token ===${NC}"
    local response=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer ${TOKEN}")
    
    local success=$(echo "$response" | jq -r '.success')
    if [ "$success" = "true" ]; then
        echo -e "${GREEN}✓${NC} Token is valid"
        echo "$response" | jq -r '.result.id, .result.status'
    else
        echo -e "${RED}✗${NC} Token is invalid"
        exit 1
    fi
}

# Main execution
case "${1:-check}" in
    check)
        verify_token
        echo ""
        list_dns_records
        echo ""
        echo -e "${YELLOW}=== Checking Required Subdomains ===${NC}"
        missing=0
        for subdomain in "${SUBDOMAINS[@]}"; do
            count=$(check_dns_record "$subdomain")
            if [ "$count" = "0" ]; then
                echo -e "${RED}✗${NC} Missing: ${subdomain}.leopaska.xyz"
                ((missing++))
            else
                echo -e "${GREEN}✓${NC} Exists: ${subdomain}.leopaska.xyz"
            fi
        done
        echo ""
        echo "Total subdomains: ${#SUBDOMAINS[@]}"
        echo "Missing records: $missing"
        ;;
    
    create)
        verify_token
        echo ""
        echo -e "${YELLOW}=== Creating Missing DNS Records ===${NC}"
        for subdomain in "${SUBDOMAINS[@]}"; do
            count=$(check_dns_record "$subdomain")
            if [ "$count" = "0" ]; then
                create_dns_record "$subdomain"
                sleep 0.5  # Rate limiting
            else
                echo -e "${YELLOW}→${NC} Exists: ${subdomain}.leopaska.xyz"
            fi
        done
        ;;
    
    list)
        list_dns_records
        ;;
    
    *)
        echo "Usage: $0 {check|create|list}"
        echo ""
        echo "  check  - Verify which DNS records exist"
        echo "  create - Create all missing DNS records"
        echo "  list   - List all current CNAME records"
        exit 1
        ;;
esac
