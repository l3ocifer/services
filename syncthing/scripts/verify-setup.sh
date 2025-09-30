#!/bin/bash

# Syncthing Setup Verification Script
# Verifies that the development environment sync is ready to go

set -e

SYNCTHING_DATA_DIR="/media/l3o/prod/docker/syncthing"
API_KEY="UjcN2jeLHr3a3tgUPZJzxL4P2M47Gjpe"
DEVICE_ID="JOTNWK3-PAPBLTD-SGEVCTK-S7RF5DW-23ZUW3Z-X22MYVX-OBVV3OZ-A4JSWQD"

echo "🔍 Syncthing Development Environment - Setup Verification"
echo "======================================================="

# Check container status
echo "📦 Checking container status..."
if docker ps | grep -q syncthing-leopaska; then
    echo "✅ Syncthing container is running"
else
    echo "❌ Syncthing container is not running"
    exit 1
fi

# Check health
echo "🏥 Checking container health..."
if docker exec syncthing-leopaska wget -q --spider http://localhost:8384; then
    echo "✅ Web UI is accessible"
else
    echo "❌ Web UI is not accessible"
    exit 1
fi

# Check mounts
echo "📁 Checking volume mounts..."
for dir in dotfiles scripts ssh-configs git-configs dev-tools; do
    if docker exec syncthing-leopaska ls /data/$dir >/dev/null 2>&1; then
        count=$(docker exec syncthing-leopaska ls /data/$dir | wc -l)
        echo "✅ $dir mounted ($count files)"
    else
        echo "❌ $dir not mounted"
        exit 1
    fi
done

# Check shared folder contents
echo "📂 Checking shared folder contents..."
for dir in dotfiles scripts ssh-configs git-configs dev-tools; do
    count=$(ls -la "$SYNCTHING_DATA_DIR/shared/$dir/" 2>/dev/null | wc -l)
    if [[ $count -gt 2 ]]; then
        echo "✅ $dir has content ($((count-2)) items)"
    else
        echo "⚠️  $dir is empty"
    fi
done

# Check critical files
echo "🔑 Checking critical files..."
critical_files=(
    "$SYNCTHING_DATA_DIR/shared/dotfiles/.zshrc"
    "$SYNCTHING_DATA_DIR/shared/dotfiles/.bashrc"
    "$SYNCTHING_DATA_DIR/shared/ssh-configs/config"
    "$SYNCTHING_DATA_DIR/shared/ssh-configs/leo-personal"
    "$SYNCTHING_DATA_DIR/shared/scripts"
)

for file in "${critical_files[@]}"; do
    if [[ -e "$file" ]]; then
        echo "✅ $(basename "$file") exists"
    else
        echo "❌ $(basename "$file") missing"
    fi
done

# Check .stignore files
echo "🚫 Checking .stignore files..."
ignore_files=(
    "$SYNCTHING_DATA_DIR/shared/.stignore"
    "$SYNCTHING_DATA_DIR/shared/dotfiles/.stignore"
    "$SYNCTHING_DATA_DIR/shared/ssh-configs/.stignore"
)

for file in "${ignore_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $(basename "$(dirname "$file")")/$(basename "$file") exists"
    else
        echo "❌ $(basename "$(dirname "$file")")/$(basename "$file") missing"
    fi
done

# Check API access
echo "🔌 Checking API access..."
if curl -s -H "X-API-Key: $API_KEY" http://localhost:8384/rest/system/status >/dev/null 2>&1; then
    echo "✅ API is accessible"
else
    echo "❌ API is not accessible"
fi

# Check device ID
echo "🆔 Checking device ID..."
current_id=$(docker exec syncthing-leopaska grep 'device id=' /var/syncthing/config/config.xml | head -1 | sed 's/.*id="\([^"]*\)".*/\1/')
if [[ "$current_id" == "$DEVICE_ID" ]]; then
    echo "✅ Device ID matches: $current_id"
else
    echo "⚠️  Device ID changed: $current_id (expected: $DEVICE_ID)"
fi

# Check network connectivity
echo "🌐 Checking network connectivity..."
if docker logs syncthing-leopaska 2>&1 | grep -q "Joined relay"; then
    echo "✅ Connected to relay network"
else
    echo "⚠️  Not connected to relay network (may still work locally)"
fi

# Summary
echo ""
echo "📋 Setup Summary:"
echo "   Container: syncthing-leopaska"
echo "   Device ID: $current_id"
echo "   Web UI: https://syncthing.leopaska.xyz"
echo "   Local UI: http://192.168.1.200:8384"
echo "   API Key: $API_KEY"
echo ""
echo "📁 Shared Folders Ready:"
echo "   - Dotfiles: /data/dotfiles"
echo "   - Scripts: /data/scripts"
echo "   - SSH Configs: /data/ssh-configs (includes private keys)"
echo "   - Git Configs: /data/git-configs"
echo "   - Dev Tools: /data/dev-tools"
echo ""
echo "🚀 Ready for MacBook setup!"
echo "   Run the macOS setup script on each MacBook to connect."

exit 0
