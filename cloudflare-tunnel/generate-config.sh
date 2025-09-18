#!/bin/bash
# Generate CloudFlare tunnel config from template with current domain

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TEMPLATE_FILE="$SCRIPT_DIR/config.template.yml"
CONFIG_FILE="$SCRIPT_DIR/config.yml"

# Source environment variables from docker-compose directory
if [ -f "/home/l3o/git/homelab/services/.env" ]; then
    source "/home/l3o/git/homelab/services/.env"
elif [ -f "/home/l3o/git/homelab/services/docker/.env" ]; then
    source "/home/l3o/git/homelab/services/docker/.env"
fi

# Default domain if not set
DOMAIN="${DOMAIN:-leopaska.xyz}"

echo "Generating CloudFlare tunnel config for domain: $DOMAIN"

# Replace template variables
sed "s/{{DOMAIN}}/$DOMAIN/g" "$TEMPLATE_FILE" > "$CONFIG_FILE"

echo "Config generated: $CONFIG_FILE"

# Validate the config
if command -v cloudflared &> /dev/null; then
    echo "Validating tunnel configuration..."
    cloudflared tunnel --config "$CONFIG_FILE" ingress validate
    echo "✅ Configuration is valid"
else
    echo "⚠️  cloudflared not found, skipping validation"
fi
