# Syncthing Development Environment - Deployment Guide

## 🚀 Quick Deployment

### 1. Setup Shared Folders on Server
```bash
cd /home/l3o/git/homelab/services
./syncthing/scripts/setup-sync-folders.sh
```

### 2. Update and Restart Syncthing Container
```bash
cd /home/l3o/git/homelab/services
docker-compose up -d syncthing
```

### 3. Configure Sync Folders in Web UI
1. Open: https://syncthing.leopaska.xyz
2. Add folders for each shared directory:
   - **Dotfiles**: `/data/dotfiles` → ID: `dotfiles`
   - **Scripts**: `/data/scripts` → ID: `scripts`
   - **SSH Configs**: `/data/ssh-configs` → ID: `ssh-configs`
   - **Git Configs**: `/data/git-configs` → ID: `git-configs`
   - **Dev Tools**: `/data/dev-tools` → ID: `dev-tools`

## 📱 MacBook Setup

### Personal MacBook
```bash
curl -fsSL https://raw.githubusercontent.com/l3ocifer/homelab/main/services/syncthing/scripts/macos-setup.sh | bash
```

### Work MacBook
```bash
curl -fsSL https://raw.githubusercontent.com/l3ocifer/homelab/main/services/syncthing/scripts/macos-setup.sh | bash
```

## 🔧 Manual Configuration Steps

### 1. Server Device ID
- **Homelab Server**: `JOTNWK3-PAPBLTD-SGEVCTK-S7RF5DW-23ZUW3Z-X22MYVX-OBVV3OZ-A4JSWQD`

### 2. Folder Mapping

| Server Path | Container Path | MacBook Path (Personal) | MacBook Path (Work) |
|-------------|----------------|-------------------------|---------------------|
| `/media/l3o/prod/docker/syncthing/shared/dotfiles` | `/data/dotfiles` | `~/dev-sync/dotfiles` | `~/work-dev-sync/dotfiles` |
| `/media/l3o/prod/docker/syncthing/shared/scripts` | `/data/scripts` | `~/dev-sync/scripts` | `~/work-dev-sync/scripts` |
| `/media/l3o/prod/docker/syncthing/shared/ssh-configs` | `/data/ssh-configs` | `~/dev-sync/ssh-configs` | `~/work-dev-sync/ssh-configs` |
| `/media/l3o/prod/docker/syncthing/shared/git-configs` | `/data/git-configs` | `~/dev-sync/git-configs` | `~/work-dev-sync/git-configs` |
| `/media/l3o/prod/docker/syncthing/shared/dev-tools` | `/data/dev-tools` | `~/dev-sync/dev-tools` | `~/work-dev-sync/dev-tools` |

### 3. Folder Configuration Settings
- **Type**: Send & Receive
- **Rescan Interval**: 3600 seconds
- **File Watcher**: Enabled
- **Ignore Patterns**: Use .stignore files
- **Versioning**: Simple File Versioning (keep 5 versions)

## 🔒 Security Configuration

### Ignore Patterns
Each folder has its own `.stignore` file:
- **Global patterns**: System files, caches, logs
- **SSH configs**: Private keys blocked, only public keys synced
- **Dotfiles**: History files and caches excluded
- **Scripts**: Temporary files excluded

### SSH Key Management
```bash
# Push local SSH configs to shared folder
ssh-sync push

# Pull shared SSH configs to local machine
ssh-sync pull
```

## 📊 Monitoring & Maintenance

### Health Checks
```bash
# Check Syncthing container status
docker ps | grep syncthing

# View Syncthing logs
docker logs syncthing-leopaska

# Check sync status via API
curl -H "X-API-Key: UjcN2jeLHr3a3tgUPZJzxL4P2M47Gjpe" \
  http://192.168.1.200:8384/rest/system/status
```

### Backup Configuration
```bash
# Backup Syncthing configuration
sudo tar -czf /media/l3o/prod/backups/syncthing-$(date +%Y%m%d).tar.gz \
  /media/l3o/prod/docker/syncthing/
```

### Update Syncthing
```bash
cd /home/l3o/git/homelab/services
docker-compose pull syncthing
docker-compose up -d syncthing
```

## 🚨 Troubleshooting

### Common Issues

1. **Connection Problems**
   - Check firewall: ports 8384, 22000, 21027
   - Verify device IDs are correct
   - Ensure network connectivity

2. **Sync Conflicts**
   - Review .stignore patterns
   - Check file permissions
   - Resolve conflicts in web UI

3. **Performance Issues**
   - Monitor disk space on /media/l3o/prod
   - Check memory usage (container limit: 1GB)
   - Review large file patterns in .stignore

### Log Locations
- **Server**: `docker logs syncthing-leopaska`
- **macOS**: `~/Library/Logs/Syncthing/`
- **Linux**: `~/.local/state/syncthing/`

### Reset Configuration
```bash
# Stop container
docker-compose down syncthing

# Backup and reset config
sudo mv /media/l3o/prod/docker/syncthing/config \
  /media/l3o/prod/docker/syncthing/config.backup.$(date +%Y%m%d)

# Restart container (will regenerate config)
docker-compose up -d syncthing
```

## 📈 Performance Tuning

### Resource Limits
- **Memory**: 1GB limit, 256MB reservation
- **CPU**: No limit (uses available cores)
- **Disk I/O**: Monitor /media/l3o/prod usage

### Optimization Settings
- Enable file watcher for real-time sync
- Use appropriate rescan intervals
- Exclude large binary files via .stignore
- Consider selective sync for large repositories

## 🔗 Integration

### With Other Services
- **Traefik**: Web UI accessible via https://syncthing.leopaska.xyz
- **Prometheus**: Metrics available (if enabled)
- **Backup System**: Automated backups to /media/l3o/prod/backups

### API Integration
```bash
# Get system status
curl -H "X-API-Key: UjcN2jeLHr3a3tgUPZJzxL4P2M47Gjpe" \
  http://192.168.1.200:8384/rest/system/status

# Get folder status
curl -H "X-API-Key: UjcN2jeLHr3a3tgUPZJzxL4P2M47Gjpe" \
  http://192.168.1.200:8384/rest/db/status?folder=dotfiles
```
