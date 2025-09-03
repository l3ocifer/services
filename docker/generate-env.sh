#!/bin/bash

# Script to generate a .env file for testing

# Set default values
DEFAULT_DOMAIN="codeofconsciousness.com"
DEFAULT_DOMAIN_BASE="codeofconsciousness"
DEFAULT_REDIS_PASSWORD="redisstrongpassword123"
DEFAULT_POSTGRES_PASSWORD="postgresstrongpassword123"

# Get host IP address (for Linux)
HOST_IP=$(hostname -I | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
  HOST_IP="127.0.0.1"
fi

# Check if .env exists and prompt for overwrite
if [ -f .env ]; then
  read -p ".env file already exists. Overwrite? (y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
  fi
fi

# Create the .env file
cat > .env << EOL
# Generated environment file for testing
# Generated on: $(date)

# Domain configuration
DOMAIN=${1:-$DEFAULT_DOMAIN}
DOMAIN_BASE=${DOMAIN_BASE:-$DEFAULT_DOMAIN_BASE}

# Local network configuration
LOCAL_DOMAIN=localhost
LOCAL_IP=$HOST_IP

# Database passwords
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$DEFAULT_POSTGRES_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD:-$DEFAULT_REDIS_PASSWORD}

# Authelia specific settings
AUTHELIA_STORAGE_ENCRYPTION_KEY=antidisestablishmentarianism7
AUTHELIA_SESSION_SECRET=antidisestablishmentarianism7
AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET=antidisestablishmentarianism7

# Matrix/Element specific settings
MATRIX_IDENTITY_SERVER_URL=https://vector.im

# Add any other variables as needed
EOL

echo "Generated .env file with domain: ${1:-$DEFAULT_DOMAIN}"
echo "Local IP set to: $HOST_IP"
echo "You can now test your configuration with 'docker-compose up'" 