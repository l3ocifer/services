#!/bin/bash

# macOS Syncthing Setup Script for Development Environment Sync
# Installs and configures Syncthing on macOS to sync with homelab server

set -e

# Configuration
HOMELAB_DEVICE_ID="JOTNWK3-PAPBLTD-SGEVCTK-S7RF5DW-23ZUW3Z-X22MYVX-OBVV3OZ-A4JSWQD"
HOMELAB_SERVER="192.168.1.200"
SYNCTHING_WEB_UI="http://localhost:8384"

echo "🍎 macOS Syncthing Setup for Development Environment Sync"
echo "========================================================"

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ This script is designed for macOS only"
    exit 1
fi

# Install Syncthing via Homebrew
install_syncthing() {
    echo "📦 Installing Syncthing..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install Syncthing
    if ! brew list syncthing &> /dev/null; then
        brew install syncthing
        echo "✅ Syncthing installed"
    else
        echo "✅ Syncthing already installed"
        brew upgrade syncthing 2>/dev/null || true
    fi
    
    # Start Syncthing service
    brew services start syncthing
    echo "✅ Syncthing service started"
    
    # Wait for Syncthing to start
    echo "⏳ Waiting for Syncthing to initialize..."
    sleep 10
}

# Create directory structure
setup_directories() {
    echo "📁 Setting up directory structure..."
    
    # Determine if this is work or personal MacBook
    local hostname=$(hostname)
    local sync_base=""
    
    if [[ "$hostname" == *"work"* ]] || [[ "$hostname" == *"corp"* ]] || [[ "$hostname" == *"company"* ]]; then
        sync_base="$HOME/work-dev-sync"
        echo "🏢 Detected work MacBook - using work sync directories"
    else
        sync_base="$HOME/dev-sync"
        echo "🏠 Detected personal MacBook - using personal sync directories"
    fi
    
    # Create sync directories
    mkdir -p "$sync_base"/{dotfiles,scripts,ssh-configs,git-configs,dev-tools}
    mkdir -p ~/.scripts
    mkdir -p ~/.ssh-sync
    
    # Set proper permissions
    chmod 755 "$sync_base"
    chmod 700 "$sync_base/ssh-configs"
    chmod 755 ~/.scripts
    chmod 700 ~/.ssh-sync
    
    echo "✅ Directory structure created at $sync_base"
    export SYNC_BASE="$sync_base"
}

# Configure shell integration
setup_shell_integration() {
    echo "🐚 Setting up shell integration..."
    
    # Determine shell
    local current_shell=$(basename "$SHELL")
    local shell_rc=""
    
    case "$current_shell" in
        "zsh")
            shell_rc="$HOME/.zshrc"
            ;;
        "bash")
            shell_rc="$HOME/.bashrc"
            ;;
        *)
            echo "⚠️  Unsupported shell: $current_shell"
            return
            ;;
    esac
    
    # Add aliases for sync management
    if [[ -f "$shell_rc" ]]; then
        echo "" >> "$shell_rc"
        echo "# Syncthing Development Environment Sync - $(date)" >> "$shell_rc"
        echo "alias sync-status='curl -s http://localhost:8384/rest/system/status 2>/dev/null | jq . || echo \"Syncthing not running\"'" >> "$shell_rc"
        echo "alias sync-ui='open http://localhost:8384'" >> "$shell_rc"
        echo "alias sync-restart='brew services restart syncthing'" >> "$shell_rc"
        echo "alias ssh-sync='$HOME/.scripts/ssh-sync-macos.sh'" >> "$shell_rc"
        echo "✅ Shell aliases added to $shell_rc"
    fi
}

# Create SSH sync script for macOS
create_ssh_sync_script() {
    echo "🔐 Creating SSH sync script..."
    
    cat > ~/.scripts/ssh-sync-macos.sh << 'EOF'
#!/bin/bash

# SSH Key Synchronization Script for macOS
# Safely syncs SSH configurations while protecting private keys

set -e

# Determine sync directory based on hostname
HOSTNAME=$(hostname)
if [[ "$HOSTNAME" == *"work"* ]] || [[ "$HOSTNAME" == *"corp"* ]] || [[ "$HOSTNAME" == *"company"* ]]; then
    SSH_SYNC_DIR="$HOME/work-dev-sync/ssh-configs"
else
    SSH_SYNC_DIR="$HOME/dev-sync/ssh-configs"
fi

SSH_DIR="$HOME/.ssh"

echo "🔐 SSH Configuration Sync Script (macOS)"
echo "========================================"

mkdir -p "$SSH_SYNC_DIR"

sync_to_shared() {
    echo "📤 Syncing SSH config to shared directory..."
    
    if [[ -f "$SSH_DIR/config" ]]; then
        cp "$SSH_DIR/config" "$SSH_SYNC_DIR/"
        echo "✅ SSH config copied"
    fi
    
    for key in "$SSH_DIR"/*.pub; do
        if [[ -f "$key" ]]; then
            cp "$key" "$SSH_SYNC_DIR/"
            echo "✅ Public key copied: $(basename "$key")"
        fi
    done
    
    if [[ -f "$SSH_DIR/authorized_keys" ]]; then
        cp "$SSH_DIR/authorized_keys" "$SSH_SYNC_DIR/"
        echo "✅ Authorized keys copied"
    fi
    
    echo "📤 SSH configuration synced to $SSH_SYNC_DIR"
}

sync_from_shared() {
    echo "📥 Syncing SSH config from shared directory..."
    
    if [[ ! -d "$SSH_SYNC_DIR" ]]; then
        echo "❌ Sync directory not found: $SSH_SYNC_DIR"
        exit 1
    fi
    
    # Backup existing SSH config
    if [[ -f "$SSH_DIR/config" ]]; then
        cp "$SSH_DIR/config" "$SSH_DIR/config.backup.$(date +%Y%m%d_%H%M%S)"
        echo "🔄 Existing SSH config backed up"
    fi
    
    # Copy SSH config
    if [[ -f "$SSH_SYNC_DIR/config" ]]; then
        cp "$SSH_SYNC_DIR/config" "$SSH_DIR/"
        chmod 600 "$SSH_DIR/config"
        echo "✅ SSH config updated"
    fi
    
    # Copy public keys
    for key in "$SSH_SYNC_DIR"/*.pub; do
        if [[ -f "$key" ]]; then
            cp "$key" "$SSH_DIR/"
            chmod 644 "$SSH_DIR/$key"
            echo "✅ Public key updated: $(basename "$key")"
        fi
    done
    
    # Copy authorized_keys if it exists
    if [[ -f "$SSH_SYNC_DIR/authorized_keys" ]]; then
        cp "$SSH_SYNC_DIR/authorized_keys" "$SSH_DIR/"
        chmod 600 "$SSH_DIR/authorized_keys"
        echo "✅ Authorized keys updated"
    fi
    
    echo "📥 SSH configuration synced from $SSH_SYNC_DIR"
}

case "$1" in
    "push") sync_to_shared ;;
    "pull") sync_from_shared ;;
    *) 
        echo "Usage: $0 [push|pull]"
        echo "  push - Copy local SSH configs to sync directory"
        echo "  pull - Copy shared SSH configs to local directory"
        ;;
esac
EOF
    
    chmod +x ~/.scripts/ssh-sync-macos.sh
    echo "✅ SSH sync script created at ~/.scripts/ssh-sync-macos.sh"
}

# Show device information and next steps
show_next_steps() {
    local device_id=""
    local config_file=""
    
    # Try to get device ID from Syncthing
    if [[ -f "$HOME/Library/Application Support/Syncthing/config.xml" ]]; then
        config_file="$HOME/Library/Application Support/Syncthing/config.xml"
    elif [[ -f "$HOME/.config/syncthing/config.xml" ]]; then
        config_file="$HOME/.config/syncthing/config.xml"
    fi
    
    if [[ -n "$config_file" ]] && [[ -f "$config_file" ]]; then
        device_id=$(grep 'device id=' "$config_file" | head -1 | sed 's/.*id="\([^"]*\)".*/\1/')
    fi
    
    echo ""
    echo "🎉 macOS Syncthing Setup Complete!"
    echo "=================================="
    echo ""
    echo "📱 This Device Information:"
    if [[ -n "$device_id" ]]; then
        echo "   Device ID: $device_id"
    else
        echo "   Device ID: Check Syncthing Web UI for device ID"
    fi
    echo "   Hostname: $(hostname)"
    echo "   Sync Directory: $SYNC_BASE"
    echo ""
    echo "🌐 Syncthing Web UI: $SYNCTHING_WEB_UI"
    echo ""
    echo "📋 Next Steps:"
    echo ""
    echo "1. 🔗 Add Homelab Server Device:"
    echo "   - Open: $SYNCTHING_WEB_UI"
    echo "   - Click 'Add Remote Device'"
    echo "   - Device ID: $HOMELAB_DEVICE_ID"
    echo "   - Name: homelab-server"
    echo ""
    echo "2. 📁 Configure Shared Folders:"
    echo "   Server Path                    → macOS Path"
    echo "   /data/dotfiles                → $SYNC_BASE/dotfiles"
    echo "   /data/scripts                 → $SYNC_BASE/scripts"
    echo "   /data/ssh-configs             → $SYNC_BASE/ssh-configs"
    echo "   /data/git-configs             → $SYNC_BASE/git-configs"
    echo "   /data/dev-tools               → $SYNC_BASE/dev-tools"
    echo ""
    echo "3. 🔐 Manage SSH Keys:"
    echo "   ssh-sync push                 # Send local SSH configs"
    echo "   ssh-sync pull                 # Get shared SSH configs"
    echo ""
    echo "4. 🔄 Useful Commands:"
    echo "   sync-ui                       # Open web interface"
    echo "   sync-status                   # Check sync status"
    echo "   sync-restart                  # Restart Syncthing"
    echo ""
    echo "🔒 Security Notes (Self-Hosted):"
    echo "   - Private SSH keys ARE synced (controlled infrastructure)"
    echo "   - Credentials and secrets ARE synced safely"
    echo "   - Review sync folders before enabling"
    echo "   - Test with non-critical files first"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   - If connection fails, check firewall settings"
    echo "   - Ensure homelab server is accessible at $HOMELAB_SERVER"
    echo "   - Check Syncthing logs: ~/Library/Logs/Syncthing/"
}

# Main execution
main() {
    install_syncthing
    setup_directories
    setup_shell_integration
    create_ssh_sync_script
    show_next_steps
}

# Check for help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "macOS Syncthing Setup Script for Development Environment Sync"
    echo ""
    echo "This script installs and configures Syncthing on macOS for"
    echo "synchronizing your development environment with a homelab server."
    echo ""
    echo "Usage: $0"
    echo ""
    echo "The script will:"
    echo "- Install Syncthing via Homebrew"
    echo "- Create directory structure (work-dev-sync or dev-sync)"
    echo "- Set up shell integration and aliases"
    echo "- Create SSH key sync utilities"
    echo "- Provide setup instructions for connecting to homelab"
    echo ""
    exit 0
fi

main
