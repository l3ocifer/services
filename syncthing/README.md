# Syncthing Development Environment Sync

This directory contains the Infrastructure as Code (IaC) configuration for Syncthing, which synchronizes development environments between the homelab server and MacBooks.

## 🏗 Architecture

- **Data Location**: `/media/l3o/prod/docker/syncthing/` (4TB SSD)
- **Container**: Already running as `syncthing-leopaska`
- **Web UI**: https://syncthing.leopaska.xyz or http://192.168.1.200:8384
- **API Key**: Available in `/media/l3o/prod/docker/syncthing/config/config.xml`

## 📁 Sync Folders Structure

```
/media/l3o/prod/docker/syncthing/shared/
├── dotfiles/          # .zshrc, .bashrc, shell configs
├── scripts/           # ~/.scripts/ directory
├── ssh-configs/       # SSH configurations (public keys only)
├── git-configs/       # Git configurations and hooks
└── dev-tools/         # Development tool configurations
```

## 🔒 Security (Self-Hosted Model)

- **Private SSH keys ARE synced** (self-hosted infrastructure = safe)
- **Credentials and secrets ARE synced** (controlled environment)
- Only temporary/cache files are excluded via ignore patterns
- Each sync folder has its own .stignore file for optimization

## 🚀 Usage

### Server Side (Homelab)
The server is already running. Sync folders are configured via the web UI at:
- https://syncthing.leopaska.xyz
- http://192.168.1.200:8384

### MacBook Setup
1. Install Syncthing: `brew install syncthing`
2. Start service: `brew services start syncthing`
3. Open web UI: http://localhost:8384
4. Add server device ID: `JOTNWK3-PAPBLTD-SGEVCTK-S7RF5DW-23ZUW3Z-X22MYVX-OBVV3OZ-A4JSWQD`
5. Configure shared folders as needed

## 📋 Management

### View Syncthing Status
```bash
# Check container
docker ps | grep syncthing

# View logs
docker logs syncthing-leopaska

# Access container
docker exec -it syncthing-leopaska sh
```

### Backup Configuration
```bash
# Backup Syncthing config
sudo tar -czf /media/l3o/prod/backups/syncthing-config-$(date +%Y%m%d).tar.gz \
  /media/l3o/prod/docker/syncthing/config/
```

## 🔧 Folder Configuration

Each sync folder should be configured with:
- **Type**: Send & Receive
- **Rescan Interval**: 3600s (1 hour)
- **File Watcher**: Enabled
- **Ignore Patterns**: See respective .stignore files

## 🎯 Device IDs

- **Homelab Server**: `JOTNWK3-PAPBLTD-SGEVCTK-S7RF5DW-23ZUW3Z-X22MYVX-OBVV3OZ-A4JSWQD`
- **Personal MacBook**: (To be added)
- **Work MacBook**: (To be added)

## 📊 Monitoring

Syncthing metrics are available through:
- Web UI dashboard
- Prometheus metrics (if enabled)
- Container health checks
- Traefik routing status
