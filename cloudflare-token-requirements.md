# CloudFlare API Token Requirements

## Current Tokens Status

1. **Token 1** (`ZPovc0yXoXFiCek5Bd8VBTu-7XSWWhVM5iSomtHm`)
   - ✅ Valid and active
   - ✅ Can verify zones
   - ❌ Cannot modify SSL settings
   - Limited to single zone

2. **Token 2** (`n8FexjWXbBPxAIzS8Q1U5d5cnfFHpRo5jjew3ml2`)
   - ✅ Valid and active
   - ✅ Can READ all zones and settings (including SSL mode)
   - ❌ Cannot MODIFY any settings
   - Read-only access

## What You Need to Fix SSL Warnings

To fix the "dangerous site" SSL warnings, you need a token with **WRITE** permissions for:

### Required Permissions (Must Have All)

1. **Zone → Zone Settings → Edit**
   - Needed to change SSL mode from "Full" to "Flexible"
   - Needed to enable "Always Use HTTPS"
   - Needed to enable "Automatic HTTPS Rewrites"

2. **Zone → SSL and Certificates → Edit**
   - Needed to modify SSL/TLS encryption settings

3. **Zone Resources**
   - Include → Specific Zone → `leopaska.xyz`
   - Or: Include → All zones

## How to Create the Correct Token

1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Click **"Create Token"**
3. Choose **"Custom token"** template
4. Give it a name like: "Homelab SSL Manager"
5. Set permissions:
   ```
   Permission 1:
   - Zone → Zone Settings → Edit

   Permission 2:
   - Zone → SSL and Certificates → Edit

   Zone Resources:
   - Include → Specific zone → leopaska.xyz
   ```
6. Continue to summary
7. Create token
8. Copy the token

## Test Your New Token

Once created, test it with this command:

```bash
# Replace YOUR_NEW_TOKEN with the actual token
TOKEN="YOUR_NEW_TOKEN"

# Test 1: Verify token
curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $TOKEN" | jq '.success'

# Test 2: Can it READ SSL settings?
curl -s "https://api.cloudflare.com/client/v4/zones/7ec42a804e4137fa29452223b5f82d26/settings/ssl" \
  -H "Authorization: Bearer $TOKEN" | jq '.result.value'

# Test 3: Can it WRITE SSL settings? (dry run)
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/7ec42a804e4137fa29452223b5f82d26/settings/ssl" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"flexible"}' | jq '.success'
```

If all three tests return `true` or show values, the token is ready!

## Quick Fix Once You Have the Right Token

```bash
# Run the fix script with the new token
./fix-ssl.sh YOUR_NEW_TOKEN_WITH_WRITE_PERMISSIONS

# Or update your environment permanently
echo 'export CLOUDFLARE_API_TOKEN="YOUR_NEW_TOKEN"' >> ~/.zshrc
source ~/.zshrc
./fix-ssl.sh
```

## Why Current Tokens Don't Work

- **Token 1**: Has zone access but lacks SSL modification permissions
- **Token 2**: Can read everything but is explicitly read-only
- **What's needed**: A token that can both READ and WRITE SSL settings for leopaska.xyz

The fix requires changing CloudFlare's SSL mode from "Full" (expects HTTPS backend) to "Flexible" (allows HTTP backend), which needs write permissions.