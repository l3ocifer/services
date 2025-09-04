# External Access Setup for Route53 Domain

## Overview
This guide shows how to make your locally deployed projects available on your Route53 domain with basic authentication.

## Step 1: DNS Configuration

In your Route53 console, create these records:

### A Records
- **Name**: `leopaska.com`
- **Type**: A
- **Value**: `108.51.59.178`
- **TTL**: 300

- **Name**: `*.leopaska.com`
- **Type**: A
- **Value**: `108.51.59.178`
- **TTL**: 300

## Step 2: Environment Configuration

Create `/home/l3o/git/homelab/services/docker/.env` with:

```bash
# Domain configuration
DOMAIN=leopaska.com
DOMAIN_BASE=leopaska

# Local network configuration
LOCAL_DOMAIN=localhost
LOCAL_IP=108.51.59.178

# Database passwords
POSTGRES_PASSWORD=postgresstrongpassword123
REDIS_PASSWORD=redisstrongpassword123

# Let's Encrypt configuration
ACME_EMAIL=admin@leopaska.com

# Basic Auth credentials (htpasswd format) - Only for admin services
TRAEFIK_AUTH=admin-leopaska:$$apr1$$YPwrnlVM$$w9eKVEBoLqdixVwFYzZzh1
RUSTPAD_AUTH=admin-leopaska:$$apr1$$8tZvSTfN$$6sm0foSfqranEmCXjPiYc1
# Note: OpenWebUI uses its own authentication system (no basic auth needed)

# Additional service passwords
GRAFANA_PASSWORD=admin_password
COOLIFY_PASSWORD=admin_password
VAULTWARDEN_ADMIN_TOKEN=admin_token_here
HUGINN_INVITATION_CODE=demo-access
HUGINN_ADMIN_USERNAME=admin
HUGINN_ADMIN_PASSWORD=admin_password
POSTIZ_JWT_SECRET=jwt_secret_here
POSTIZ_ALLOW_SIGNUP=false
UMAMI_HASH_SALT=random-salt-here
PIHOLE_PASSWORD=admin_password
PGADMIN_EMAIL=admin@leopaska.com
PGADMIN_PASSWORD=admin_password
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
CLICKHOUSE_PASSWORD=clickhouse_password
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=admin_password
MONGO_USERNAME=admin
MONGO_PASSWORD=password

# Resource limits
HOMEASSISTANT_MEMORY_LIMIT=2G
OLLAMA_MEMORY_LIMIT=32G
OLLAMA_MEMORY_RESERVATION=16G
POSTGRES_MEMORY_LIMIT=4G
REDIS_MEMORY_LIMIT=1G
MONITORING_MEMORY_LIMIT=4G
HUGINN_MEMORY_LIMIT=2G

# Data directory
DATA_DIR=/mnt/data
TZ=UTC
```

## Step 3: Update Traefik Security Configuration

Update `/home/l3o/git/homelab/services/docker/traefik/config/security.yml`:

```yaml
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

    # Global basic auth for external access
    external-auth:
      basicAuth:
        users:
          - "demo:$$apr1$$YPwrnlVM$$w9eKVEBoLqdixVwFYzZzh1"  # demo/demo
        removeHeader: true

    traefik-auth:
      basicAuth:
        users:
          - "admin-leopaska:$$apr1$$YPwrnlVM$$w9eKVEBoLqdixVwFYzZzh1"
        removeHeader: true

    rustpad-auth:
      basicAuth:
        users:
          - "admin-leopaska:$$apr1$$8tZvSTfN$$6sm0foSfqranEmCXjPiYc1"
        removeHeader: true

    webui-auth:
      basicAuth:
        users:
          - "admin-leopaska:$$apr1$$bRtp8Cqq$$WrIO6E8DaVJmgz2a9r7TZ1"
        removeHeader: true

    local-only:
      ipWhiteList:
        sourceRange:
          - "127.0.0.1/32"  # localhost
          - "10.0.0.0/8"    # private network
          - "172.16.0.0/12" # private network (includes Docker)
          - "192.168.0.0/16" # private network
```

## Step 4: Firewall Configuration

```bash
# Allow HTTP and HTTPS traffic
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check firewall status
sudo ufw status
```

## Step 5: Deploy Services

```bash
cd /home/l3o/git/homelab/services/docker
docker-compose up -d
```

## Step 6: Test External Access

Your services will be available at:

### Homelab Services
- **Traefik Dashboard**: https://traefik.leopaska.com
- **Grafana**: https://grafana.leopaska.com
- **Prometheus**: https://metrics.leopaska.com
- **Home Assistant**: https://home.leopaska.com
- **OpenWebUI**: https://chat.leopaska.com
- **RustPad**: https://pad.leopaska.com
- **n8n**: https://n8n.leopaska.com
- **Coolify**: https://coolify.leopaska.com
- **Matrix**: https://matrix.leopaska.com
- **Element**: https://chat-matrix.leopaska.com
- **Vaultwarden**: https://vault.leopaska.com
- **SpaceDrive**: https://drive.leopaska.com

### Production Projects
- **DiscoverLocal AI**: https://discoverlocal.leopaska.com
- **HyvaPaska**: https://hyvapaska.leopaska.com
- **Potluck**: https://potluck.leopaska.com
- **TheBlink Live**: https://theblink.leopaska.com
- **Omnilemma**: https://omnilemma.leopaska.com

## Basic Auth Credentials

- **Username**: `demo`
- **Password**: `demo`

## Troubleshooting

### Check SSL Certificates
```bash
# Check if certificates are being generated
docker-compose logs traefik | grep -i acme
```

### Check Service Health
```bash
# Check all services
docker-compose ps

# Check specific service logs
docker-compose logs [service-name]
```

### Test DNS Resolution
```bash
# Test domain resolution
nslookup leopaska.com
dig leopaska.com
```

## Security Notes

1. **Basic Auth**: All external access is protected with basic authentication
2. **SSL/TLS**: All traffic is encrypted with Let's Encrypt certificates
3. **Local Access**: Services remain accessible locally without auth
4. **Firewall**: Only ports 80 and 443 are exposed externally
5. **IP Whitelisting**: Local network access bypasses basic auth

## Next Steps

1. Update DNS records in Route53
2. Create the .env file
3. Update Traefik security configuration
4. Configure firewall
5. Deploy services
6. Test external access

The setup leverages your existing Traefik configuration and just adds external domain routing with basic authentication for secure access.
