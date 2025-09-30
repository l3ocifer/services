# CloudFlare CLI Setup and SSL Fix

## Current Status
- ✅ CloudFlare API Token is valid: `ZPovc0yXoXFiCek5Bd8VBTu-7XSWWhVM5iSomtHm`
- ✅ Zone ID for leopaska.xyz: `7ec42a804e4137fa29452223b5f82d26`
- ❌ Token has limited permissions (cannot modify SSL settings)

## Token Permissions Needed
Your current token is missing permissions to modify SSL settings. To fix the SSL warnings via CLI, you need a token with:

1. **Zone → SSL and Certificates → Edit**
2. **Zone → Zone Settings → Edit**

## How to Update Token Permissions

1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Find your current token (ID: `2e587d4950b5a89369ee64d8ed113a22`)
3. Click "Edit" or create a new token
4. Add these permissions:
   - Zone → SSL and Certificates → Edit
   - Zone → Zone Settings → Edit
   - Zone Resources → Include → Specific Zone → leopaska.xyz

## CLI Commands (After Token Update)

Once you have a token with proper permissions, save it:

```bash
# Update token in ~/.zshrc
echo 'export CLOUDFLARE_API_TOKEN="your-new-token-here"' >> ~/.zshrc
source ~/.zshrc
```

Then fix SSL settings with these commands:

```bash
# Set zone ID
ZONE_ID="7ec42a804e4137fa29452223b5f82d26"
TOKEN="your-new-token-here"

# Set SSL mode to Flexible
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/ssl" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"value":"flexible"}'

# Enable Always Use HTTPS
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/always_use_https" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}'

# Enable Automatic HTTPS Rewrites
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/automatic_https_rewrites" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}'
```

## Quick Fix Script

Create this script as `fix-ssl.sh`:

```bash
#!/bin/bash
set -e

# CloudFlare settings
ZONE_ID="7ec42a804e4137fa29452223b5f82d26"
TOKEN="${CLOUDFLARE_API_TOKEN}"

if [ -z "$TOKEN" ]; then
    echo "Error: CLOUDFLARE_API_TOKEN not set"
    echo "Run: export CLOUDFLARE_API_TOKEN='your-token-here'"
    exit 1
fi

echo "Fixing SSL settings for leopaska.xyz..."

# Set SSL to Flexible
echo "Setting SSL mode to Flexible..."
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/ssl" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"value":"flexible"}' | jq '.success'

# Enable Always Use HTTPS
echo "Enabling Always Use HTTPS..."
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/always_use_https" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}' | jq '.success'

# Enable Automatic HTTPS Rewrites
echo "Enabling Automatic HTTPS Rewrites..."
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/automatic_https_rewrites" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}' | jq '.success'

echo "✅ SSL settings updated! Clear browser cache and test in a few minutes."
```

## Test Commands Working

With proper permissions, test with:

```bash
# Verify token works
curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | jq '.success'

# Check SSL setting
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/ssl" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" | jq '.result.value'
```

## Alternative: Using Wrangler

We have Wrangler installed now:

```bash
# Login with token
export CLOUDFLARE_API_TOKEN="your-updated-token"
wrangler whoami

# Note: Wrangler is mainly for Workers/Pages, not zone settings
# For zone settings, use the curl commands above
```

## Summary

Your CloudFlare API token is working but lacks permissions to modify SSL settings. Update the token permissions in the CloudFlare dashboard, then use the commands above to fix the SSL warnings programmatically.