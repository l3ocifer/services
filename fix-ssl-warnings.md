# Fix SSL "Dangerous Site" Warnings

## The Issue
You're seeing "dangerous site" warnings because CloudFlare is configured for Full SSL mode but your backend services use HTTP (not HTTPS). The CloudFlare tunnel terminates SSL at the edge, but CloudFlare still expects HTTPS backend by default.

## Manual Fix (CloudFlare Dashboard)

Since we don't have API access configured, you need to fix this in the CloudFlare Dashboard:

1. **Login to CloudFlare Dashboard**
   - Go to https://dash.cloudflare.com
   - Select your domain: leopaska.xyz

2. **Configure SSL/TLS Settings**
   - Navigate to **SSL/TLS** → **Overview**
   - Change SSL encryption mode to **"Flexible"**
   - This tells CloudFlare to use HTTPS for visitors but HTTP for backend

3. **Configure Edge Certificates**
   - Go to **SSL/TLS** → **Edge Certificates**
   - Enable **"Always Use HTTPS"** - ON
   - Enable **"Automatic HTTPS Rewrites"** - ON

4. **Clear Cache**
   - Go to **Caching** → **Configuration**
   - Click **"Purge Everything"**

## Alternative: Configure Services for HTTPS

If you prefer to keep "Full" SSL mode, you need to configure services to use HTTPS internally:

```yaml
# In docker-compose.yml, add to Traefik:
- "--entrypoints.websecure.http.tls=true"
- "--entrypoints.websecure.http.tls.certresolver=cloudflare"
```

## Verification

After making changes:
1. Wait 2-5 minutes for CloudFlare to propagate
2. Clear browser cache or use incognito mode
3. Test services:
   - https://n8n.leopaska.xyz
   - https://vaultwarden.leopaska.xyz
   - https://coolify.leopaska.xyz
   - https://pgadmin.leopaska.xyz

## Why This Happens

```
[Browser] --HTTPS--> [CloudFlare Edge] --expects HTTPS--> [CloudFlare Tunnel] --HTTP--> [Traefik] --HTTP--> [Services]
                                        ^
                                        |
                                   Problem is here
```

Setting to "Flexible" mode tells CloudFlare:
```
[Browser] --HTTPS--> [CloudFlare Edge] --HTTP OK--> [CloudFlare Tunnel] --HTTP--> [Traefik] --HTTP--> [Services]
```

## Quick Test

To verify if it's working (after CloudFlare changes):
```bash
curl -I https://n8n.leopaska.xyz
# Should return HTTP 200 without SSL errors
```

## Setting up CloudFlare CLI for Future

To manage CloudFlare from CLI in the future:

1. Get your API token from CloudFlare Dashboard:
   - Go to **My Profile** → **API Tokens**
   - Create token with Zone:SSL and TLS:Edit permissions

2. Save it in your environment:
   ```bash
   echo 'export CLOUDFLARE_API_TOKEN="your-token-here"' >> ~/.zshrc
   echo 'export CLOUDFLARE_EMAIL="your-email@example.com"' >> ~/.zshrc
   ```

3. Install CloudFlare CLI:
   ```bash
   npm install -g cloudflare-cli
   # or
   pip install cloudflare
   ```

Then you can manage SSL settings via CLI:
```bash
# Example with proper token:
cf-cli zone ssl-mode flexible --zone leopaska.xyz
```