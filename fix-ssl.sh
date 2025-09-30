#!/bin/bash
set -e

# CloudFlare settings
ZONE_ID="7ec42a804e4137fa29452223b5f82d26"

# Check if token is provided as argument or use environment variable
if [ -n "$1" ]; then
    TOKEN="$1"
    echo "Using provided token"
elif [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    TOKEN="$CLOUDFLARE_API_TOKEN"
    echo "Using token from environment"
else
    echo "Error: Please provide CloudFlare API token as argument or set CLOUDFLARE_API_TOKEN"
    echo "Usage: ./fix-ssl.sh YOUR_API_TOKEN"
    echo "   or: export CLOUDFLARE_API_TOKEN='your-token' && ./fix-ssl.sh"
    exit 1
fi

echo "================================================"
echo "Fixing SSL settings for leopaska.xyz..."
echo "================================================"

# Verify token works
echo -n "1. Verifying API token... "
VERIFY=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

if echo "$VERIFY" | jq -e '.success' > /dev/null 2>&1; then
    echo "✓ Token is valid"
else
    echo "✗ Token verification failed"
    echo "$VERIFY" | jq '.'
    exit 1
fi

# Check current SSL setting
echo -n "2. Current SSL mode: "
CURRENT_SSL=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/ssl" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

if echo "$CURRENT_SSL" | jq -e '.success' > /dev/null 2>&1; then
    echo "$CURRENT_SSL" | jq -r '.result.value'
else
    echo "Unable to retrieve (may need permissions)"
fi

# Set SSL to Flexible
echo -n "3. Setting SSL mode to Flexible... "
SSL_RESULT=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/ssl" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"value":"flexible"}')

if echo "$SSL_RESULT" | jq -e '.success' > /dev/null 2>&1; then
    echo "✓ Success"
else
    echo "✗ Failed"
    echo "$SSL_RESULT" | jq '.errors'
fi

# Enable Always Use HTTPS
echo -n "4. Enabling Always Use HTTPS... "
HTTPS_RESULT=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/always_use_https" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}')

if echo "$HTTPS_RESULT" | jq -e '.success' > /dev/null 2>&1; then
    echo "✓ Success"
else
    echo "✗ Failed"
    echo "$HTTPS_RESULT" | jq '.errors'
fi

# Enable Automatic HTTPS Rewrites
echo -n "5. Enabling Automatic HTTPS Rewrites... "
REWRITES_RESULT=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/automatic_https_rewrites" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}')

if echo "$REWRITES_RESULT" | jq -e '.success' > /dev/null 2>&1; then
    echo "✓ Success"
else
    echo "✗ Failed"
    echo "$REWRITES_RESULT" | jq '.errors'
fi

echo ""
echo "================================================"
echo "✅ SSL configuration complete!"
echo "================================================"
echo ""
echo "Changes will take effect in 1-5 minutes."
echo "Clear your browser cache or use incognito mode to test."
echo ""
echo "Test URLs:"
echo "  - https://n8n.leopaska.xyz"
echo "  - https://vaultwarden.leopaska.xyz"
echo "  - https://coolify.leopaska.xyz"
echo "  - https://pgadmin.leopaska.xyz"