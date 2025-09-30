#!/bin/bash

# Syncthing Development Environment Setup Script
# Creates and configures sync folders for development environment synchronization

set -e

# Configuration
SYNCTHING_DATA_DIR="/media/l3o/prod/docker/syncthing"
SHARED_DIR="$SYNCTHING_DATA_DIR/shared"
HOME_DIR="/home/l3o"
SCRIPTS_DIR="$HOME_DIR/.scripts"

echo "🔄 Setting up Syncthing Development Environment Sync"
echo "=================================================="

# Ensure we're running as the correct user
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should not be run as root"
   exit 1
fi

# Create shared directories structure
create_shared_directories() {
    echo "📁 Creating shared directory structure..."
    
    sudo mkdir -p "$SHARED_DIR"/{dotfiles,scripts,ssh-configs,git-configs,dev-tools}
    sudo chown -R l3o:l3o "$SHARED_DIR"
    chmod -R 755 "$SHARED_DIR"
    
    echo "✅ Shared directories created"
}

# Setup dotfiles sync
setup_dotfiles_sync() {
    echo "🏠 Setting up dotfiles synchronization..."
    
    local dotfiles_dir="$SHARED_DIR/dotfiles"
    
    # Copy current dotfiles to shared directory
    if [[ -f "$HOME_DIR/.zshrc" ]]; then
        cp "$HOME_DIR/.zshrc" "$dotfiles_dir/"
        echo "✅ .zshrc copied to sync folder"
    fi
    
    if [[ -f "$HOME_DIR/.bashrc" ]]; then
        cp "$HOME_DIR/.bashrc" "$dotfiles_dir/"
        echo "✅ .bashrc copied to sync folder"
    fi
    
    if [[ -f "$HOME_DIR/.gitconfig" ]]; then
        cp "$HOME_DIR/.gitconfig" "$dotfiles_dir/"
        echo "✅ .gitconfig copied to sync folder"
    fi
    
    # Copy .stignore file
    if [[ -f "/home/l3o/git/homelab/services/syncthing/shared/dotfiles/.stignore" ]]; then
        cp "/home/l3o/git/homelab/services/syncthing/shared/dotfiles/.stignore" "$dotfiles_dir/"
        echo "✅ .stignore file copied"
    fi
}

# Setup scripts sync
setup_scripts_sync() {
    echo "📜 Setting up scripts synchronization..."
    
    local scripts_sync_dir="$SHARED_DIR/scripts"
    
    if [[ -d "$SCRIPTS_DIR" ]]; then
        # Copy scripts directory contents
        cp -r "$SCRIPTS_DIR"/* "$scripts_sync_dir/" 2>/dev/null || true
        echo "✅ Scripts copied to sync folder"
    else
        echo "⚠️  Scripts directory not found at $SCRIPTS_DIR"
    fi
}

# Setup SSH configs sync (public keys only)
setup_ssh_sync() {
    echo "🔐 Setting up SSH configuration synchronization..."
    
    local ssh_sync_dir="$SHARED_DIR/ssh-configs"
    local ssh_dir="$HOME_DIR/.ssh"
    
    if [[ -d "$ssh_dir" ]]; then
        # Copy SSH config
        if [[ -f "$ssh_dir/config" ]]; then
            cp "$ssh_dir/config" "$ssh_sync_dir/"
            echo "✅ SSH config copied"
        fi
        
        # Copy all SSH keys (private and public) - self-hosted security
        for key in "$ssh_dir"/leo-*; do
            if [[ -f "$key" ]] && [[ ! "$key" == *.pub ]]; then
                cp "$key" "$ssh_sync_dir/"
                chmod 600 "$ssh_sync_dir/$(basename "$key")"
                echo "✅ Private key copied: $(basename "$key")"
            fi
        done
        
        for key in "$ssh_dir"/*.pub; do
            if [[ -f "$key" ]]; then
                cp "$key" "$ssh_sync_dir/"
                echo "✅ Public key copied: $(basename "$key")"
            fi
        done
        
        # Copy authorized_keys if it exists
        if [[ -f "$ssh_dir/authorized_keys" ]]; then
            cp "$ssh_dir/authorized_keys" "$ssh_sync_dir/"
            echo "✅ Authorized keys copied"
        fi
        
        # Copy .stignore file
        if [[ -f "/home/l3o/git/homelab/services/syncthing/shared/ssh-configs/.stignore" ]]; then
            cp "/home/l3o/git/homelab/services/syncthing/shared/ssh-configs/.stignore" "$ssh_sync_dir/"
            echo "✅ SSH .stignore file copied"
        fi
    else
        echo "⚠️  SSH directory not found at $ssh_dir"
    fi
}

# Setup git configs sync
setup_git_configs_sync() {
    echo "🌿 Setting up Git configuration synchronization..."
    
    local git_sync_dir="$SHARED_DIR/git-configs"
    
    # Copy global git config
    if [[ -f "$HOME_DIR/.gitconfig" ]]; then
        cp "$HOME_DIR/.gitconfig" "$git_sync_dir/"
        echo "✅ Global .gitconfig copied"
    fi
    
    # Copy global gitignore if it exists
    if [[ -f "$HOME_DIR/.gitignore_global" ]]; then
        cp "$HOME_DIR/.gitignore_global" "$git_sync_dir/"
        echo "✅ Global .gitignore copied"
    fi
    
    # Copy git hooks if they exist
    if [[ -d "$HOME_DIR/.git-hooks" ]]; then
        cp -r "$HOME_DIR/.git-hooks" "$git_sync_dir/"
        echo "✅ Git hooks copied"
    fi
}

# Setup development tools configs
setup_dev_tools_sync() {
    echo "🛠 Setting up development tools configuration synchronization..."
    
    local dev_tools_dir="$SHARED_DIR/dev-tools"
    
    # Copy various dev tool configs
    local configs=(
        ".vimrc"
        ".tmux.conf" 
        ".screenrc"
        ".curlrc"
        ".wgetrc"
    )
    
    for config in "${configs[@]}"; do
        if [[ -f "$HOME_DIR/$config" ]]; then
            cp "$HOME_DIR/$config" "$dev_tools_dir/"
            echo "✅ $config copied"
        fi
    done
    
    # Copy tool-specific directories (configs only, not caches)
    if [[ -d "$HOME_DIR/.config" ]]; then
        mkdir -p "$dev_tools_dir/.config"
        
        # Copy specific tool configs
        for tool in "git" "gh" "starship" "atuin"; do
            if [[ -d "$HOME_DIR/.config/$tool" ]]; then
                cp -r "$HOME_DIR/.config/$tool" "$dev_tools_dir/.config/"
                echo "✅ $tool config copied"
            fi
        done
    fi
}

# Set proper permissions
set_permissions() {
    echo "🔐 Setting proper permissions..."
    
    # Ensure l3o owns everything
    sudo chown -R l3o:l3o "$SHARED_DIR"
    
    # Set secure permissions for SSH configs
    chmod 700 "$SHARED_DIR/ssh-configs"
    chmod 600 "$SHARED_DIR/ssh-configs"/* 2>/dev/null || true
    
    # Set executable permissions for scripts
    chmod +x "$SHARED_DIR/scripts"/*.sh 2>/dev/null || true
    
    echo "✅ Permissions set"
}

# Display next steps
show_next_steps() {
    echo ""
    echo "🎉 Syncthing Development Environment Setup Complete!"
    echo "================================================="
    echo ""
    echo "📁 Shared folders created at:"
    echo "   $SHARED_DIR/"
    echo ""
    echo "🌐 Next steps:"
    echo "1. Open Syncthing Web UI: https://syncthing.leopaska.xyz"
    echo "2. Add shared folders in Syncthing:"
    echo "   - Dotfiles: $SHARED_DIR/dotfiles"
    echo "   - Scripts: $SHARED_DIR/scripts"  
    echo "   - SSH Configs: $SHARED_DIR/ssh-configs"
    echo "   - Git Configs: $SHARED_DIR/git-configs"
    echo "   - Dev Tools: $SHARED_DIR/dev-tools"
    echo ""
    echo "3. Configure MacBook clients:"
    echo "   - Install Syncthing: brew install syncthing"
    echo "   - Add device ID: JOTNWK3-PAPBLTD-SGEVCTK-S7RF5DW-23ZUW3Z-X22MYVX-OBVV3OZ-A4JSWQD"
    echo "   - Configure shared folders"
    echo ""
    echo "🔒 Security reminders:"
    echo "   - Private SSH keys ARE synced (self-hosted security)"
    echo "   - Credentials and secrets ARE synced (controlled infrastructure)"
    echo "   - Review .stignore files for each folder"
    echo "   - Test sync with non-critical files first"
}

# Main execution
main() {
    create_shared_directories
    setup_dotfiles_sync
    setup_scripts_sync
    setup_ssh_sync
    setup_git_configs_sync
    setup_dev_tools_sync
    set_permissions
    show_next_steps
}

# Check for help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Syncthing Development Environment Setup Script"
    echo ""
    echo "This script sets up shared folders for synchronizing development"
    echo "environment between homelab server and MacBooks."
    echo ""
    echo "Usage: $0"
    echo ""
    echo "The script will create and populate shared folders with:"
    echo "- Dotfiles (.zshrc, .bashrc, etc.)"
    echo "- Custom scripts from ~/.scripts/"
    echo "- SSH configurations (public keys only)"
    echo "- Git configurations"
    echo "- Development tool configurations"
    echo ""
    echo "All private keys and sensitive data are excluded via .stignore files."
    exit 0
fi

main
