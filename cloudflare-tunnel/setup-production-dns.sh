#!/bin/bash
# Setup Individual DNS Records for Production
# Removes wildcard and creates explicit CNAME records for all services

set -e

ZONE_ID="7ec42a804e4137fa29452223b5f82d26"
TOKEN_CREATOR="4CiXXP1KJOmNhGMBHSmO_dy7q6tQSoCzpf7cSDid"
TUNNEL_ID="8a8129e7-f8c3-4cc4-8b1f-9995da97fff0"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Creating DNS Management Token ===${NC}"

# Create a token with DNS write permissions
DNS_TOKEN_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/user/tokens" \
  -H "Authorization: Bearer ${TOKEN_CREATOR}" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "Homelab DNS Manager (auto-created)",
    "policies": [
      {
        "effect": "allow",
        "resources": {
          "com.cloudflare.api.account.zone.'${ZONE_ID}'": "*"
        },
        "permission_groups": [
          {
            "id": "c8fed203ed3043cba015a93ad1616f1f",
            "name": "Zone Read"
          },
          {
            "id": "4755a26eedb94da69e1066d98aa820be",
            "name": "DNS Write"
          }
        ]
      }
    ]
  }')

DNS_TOKEN=$(echo "$DNS_TOKEN_RESPONSE" | jq -r '.result.value // empty')

if [ -z "$DNS_TOKEN" ]; then
    echo -e "${RED}Failed to create DNS token${NC}"
    echo "$DNS_TOKEN_RESPONSE" | jq '.errors'
    exit 1
fi

echo -e "${GREEN}✓${NC} DNS token created: ${DNS_TOKEN:0:20}..."

# All 43 subdomains from tunnel config
SUBDOMAINS=(
    "ae" "adminer" "argocd" "authelia" "blink" "conduit" "coolify"
    "discover" "element" "grafana" "grafana-k3s" "homeassistant"
    "huginn" "hyva" "ipfs" "jellyfin" "librechat" "live" "loki"
    "mailhog" "minio" "n8n" "nodeexporter" "ollama" "omni"
    "openwebui" "pgadmin" "postiz" "potluck" "prometheus"
    "prometheus-k3s" "rabbitmq" "rustdesk" "rustpad" "spacedrive"
    "syncthing" "traefik" "traefik-k3s" "umami" "uptimekuma"
    "ursulai" "vaultwarden" "whodb"
)

echo ""
echo -e "${BLUE}=== Creating Individual DNS Records ===${NC}"

created=0
exists=0
failed=0

for subdomain in "${SUBDOMAINS[@]}"; do
    # Check if record exists
    check_response=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${subdomain}.leopaska.xyz&type=CNAME" \
        -H "Authorization: Bearer ${DNS_TOKEN}")
    
    count=$(echo "$check_response" | jq -r '.result | length')
    
    if [ "$count" != "0" ]; then
        echo -e "${YELLOW}→${NC} ${subdomain}.leopaska.xyz (already exists)"
        ((exists++))
        continue
    fi
    
    # Create CNAME record
    create_response=$(curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${DNS_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{
            \"type\": \"CNAME\",
            \"name\": \"${subdomain}\",
            \"content\": \"${TUNNEL_ID}.cfargotunnel.com\",
            \"proxied\": true,
            \"ttl\": 1,
            \"comment\": \"Cloudflare Tunnel - Production Service\"
        }")
    
    success=$(echo "$create_response" | jq -r '.success')
    if [ "$success" = "true" ]; then
        echo -e "${GREEN}✓${NC} ${subdomain}.leopaska.xyz"
        ((created++))
        sleep 0.3  # Rate limiting
    else
        error_msg=$(echo "$create_response" | jq -r '.errors[0].message // "Unknown error"')
        echo -e "${RED}✗${NC} ${subdomain}.leopaska.xyz - ${error_msg}"
        ((failed++))
    fi
done

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo "  Created: $created"
echo "  Already existed: $exists"
echo "  Failed: $failed"
echo "  Total: ${#SUBDOMAINS[@]}"

# Find and remove wildcard record
echo ""
echo -e "${BLUE}=== Removing Wildcard Record ===${NC}"

wildcard_response=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=*.leopaska.xyz&type=CNAME" \
    -H "Authorization: Bearer ${DNS_TOKEN}")

wildcard_id=$(echo "$wildcard_response" | jq -r '.result[0].id // empty')

if [ -n "$wildcard_id" ]; then
    delete_response=$(curl -s -X DELETE \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${wildcard_id}" \
        -H "Authorization: Bearer ${DNS_TOKEN}")
    
    delete_success=$(echo "$delete_response" | jq -r '.success')
    if [ "$delete_success" = "true" ]; then
        echo -e "${GREEN}✓${NC} Wildcard *.leopaska.xyz removed"
    else
        echo -e "${RED}✗${NC} Failed to remove wildcard"
    fi
else
    echo -e "${YELLOW}→${NC} No wildcard record found"
fi

echo ""
echo -e "${GREEN}=== DNS Migration Complete ===${NC}"
echo "All services now use individual DNS records instead of wildcard."
echo ""

# Save token to .zshrc
echo -e "${BLUE}=== Saving DNS Token to .zshrc ===${NC}"
if ! grep -q "CLOUDFLARE_API_TOKEN_DNS" ~/.zshrc; then
    cat >> ~/.zshrc << ZSHEOF

# DNS Manager token - DNS Write for leopaska.xyz (auto-created $(date +%Y-%m-%d))
export CLOUDFLARE_API_TOKEN_DNS="${DNS_TOKEN}"
ZSHEOF
    echo -e "${GREEN}✓${NC} Token saved to ~/.zshrc"
    echo "Run: source ~/.zshrc"
else
    echo -e "${YELLOW}→${NC} CLOUDFLARE_API_TOKEN_DNS already exists in .zshrc"
    echo "To update, manually edit ~/.zshrc or remove old line first"
fi

echo ""
echo -e "${GREEN}All done! DNS is now configured with individual records.${NC}"
