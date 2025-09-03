#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print status messages
log() {
    echo -e "${YELLOW}$1${NC}"
}

error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}$1${NC}"
}

warn() {
    echo -e "${BLUE}Warning: $1${NC}"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif grep -q Microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    else
        echo "linux"
    fi
}

# Check if user has sudo access
check_sudo_access() {
    if ! sudo -v &>/dev/null; then
        error "This script requires sudo access to set up your development environment. Please ensure you have sudo privileges before running this script."
    fi
}

# Backup sudoers configuration
backup_sudoers() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="/tmp/devenv_backup_${timestamp}"
    
    log "Creating backup of sudoers configuration..."
    sudo mkdir -p "$backup_dir"
    
    # Backup main sudoers file
    if [ -f /etc/sudoers ]; then
        sudo cp /etc/sudoers "${backup_dir}/sudoers.bak"
    fi
    
    # Backup sudoers.d directory
    if [ -d /etc/sudoers.d ]; then
        sudo cp -r /etc/sudoers.d "${backup_dir}/sudoers.d.bak"
    fi
    
    success "Backup created at: ${backup_dir}"
}

# Setup passwordless sudo
setup_sudo() {
    local current_user=$(whoami)
    
    # Check if user already has passwordless sudo
    if sudo -n true 2>/dev/null; then
        success "Passwordless sudo is already configured for $current_user"
        return 0
    fi
    
    # Display security warning
    warn "SECURITY NOTICE: This script will configure passwordless sudo access for your user."
    warn "This means you won't need to enter your password for sudo commands."
    warn "This is convenient but potentially dangerous if your account is compromised."
    warn "Only proceed if you understand and accept these security implications."
    echo
    read -p "Do you want to proceed with passwordless sudo setup? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Aborted by user. Please run the script again if you change your mind."
    fi

    # Check sudo access first
    check_sudo_access
    
    # Create backup
    backup_sudoers
    
    if [[ "$OS" == "macos" ]]; then
        log "Setting up passwordless sudo for $current_user on macOS..."
        echo "$current_user ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$current_user
        sudo chmod 0440 /etc/sudoers.d/$current_user
        
        # Verify the syntax
        if ! sudo visudo -cf /etc/sudoers.d/$current_user >/dev/null 2>&1; then
            error "Invalid sudoers entry. Reverting changes..."
            sudo rm -f /etc/sudoers.d/$current_user
        fi
    else
        # For Linux/WSL
        log "Setting up passwordless sudo for $current_user on Linux..."
        echo "$current_user ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$current_user
        sudo chmod 0440 /etc/sudoers.d/$current_user
        
        # Verify the syntax
        if ! sudo visudo -cf /etc/sudoers.d/$current_user >/dev/null 2>&1; then
            error "Invalid sudoers entry. Reverting changes..."
            sudo rm -f /etc/sudoers.d/$current_user
        fi
    fi
    
    success "Passwordless sudo configured successfully for $current_user"
}

# Setup secrets file
setup_secrets() {
    local secrets_dir="$HOME/.config/personal"
    local secrets_file="$secrets_dir/secrets.yml"
    
    if [ ! -f "$secrets_file" ]; then
        log "Creating secrets template..."
        mkdir -p "$secrets_dir"
        
        cat > "$secrets_file" << 'EOL'
---
# Git Configuration
git_user_name: "Your Name"
git_user_email: "your.email@example.com"

# SSH Keys
ssh_key_type: "ed25519"
ssh_key_bits: 4096
ssh_key_comment: "your@email.com"

# GitHub Configuration
github_username: "yourusername"
github_token: ""  # Generate from https://github.com/settings/tokens

# Azure DevOps Configuration (if needed)
azure_devops_token: ""
azure_devops_organization: ""

# AWS Configuration (if needed)
aws_access_key_id: ""
aws_secret_access_key: ""
aws_default_region: ""

# Additional Tool Configurations
homebrew_github_api_token: ""  # Optional, for higher rate limits

# Paths
scripts_repo: "git@github.com:l3ocifer/scripts.git"
devenv_repo: "git@github.com:l3ocifer/devenv.git"
EOL
        
        success "Created secrets template at: $secrets_file"
        warn "Please edit $secrets_file with your personal information before continuing"
        warn "Press Enter when you're ready to continue..."
        read
        
        # Verify secrets file has been edited
        if grep -q "Your Name" "$secrets_file"; then
            error "Please edit the secrets file before continuing"
        fi
    fi
}

# Install prerequisites for macOS
setup_macos() {
    log "Setting up macOS environment..."
    
    # Install Homebrew if not present
    if ! command -v brew &>/dev/null; then
        log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error "Failed to install Homebrew"
    fi

    # Ensure Homebrew is in PATH (handle both Apple Silicon and Intel Macs)
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        error "Homebrew installation path not found"
    fi

    # Install Python and Ansible
    brew install python3 ansible || error "Failed to install Python and Ansible"
}

# Install prerequisites for Linux/WSL
setup_linux() {
    log "Setting up Linux environment..."
    
    # Update package lists
    sudo apt-get update || error "Failed to update package lists"
    
    # Install Python and pip
    sudo apt-get install -y python3 python3-pip || error "Failed to install Python"
    
    # Install Ansible
    sudo apt-get install -y ansible || error "Failed to install Ansible"
}

# Main setup
main() {
    OS=$(detect_os)
    log "Detected OS: $OS"

    # Setup secrets first
    setup_secrets

    # Setup passwordless sudo
    setup_sudo

    # Install prerequisites based on OS
    case $OS in
        macos)
            setup_macos
            ;;
        linux|wsl)
            setup_linux
            ;;
        *)
            error "Unsupported operating system"
            ;;
    esac

    # Ensure git is installed
    if ! command -v git &>/dev/null; then
        log "Installing git..."
        case $OS in
            macos)
                brew install git
                ;;
            linux|wsl)
                sudo apt-get install -y git
                ;;
        esac
    fi

    # Create git directory if it doesn't exist
    mkdir -p ~/git

    # Clone or update devenv repository
    if [ ! -d ~/git/devenv ]; then
        log "Cloning devenv repository..."
        git clone https://github.com/l3ocifer/devenv.git ~/git/devenv || error "Failed to clone devenv repository"
    else
        log "Updating devenv repository..."
        (cd ~/git/devenv && {
            # Check for any changes (including untracked files)
            if ! git diff-index --quiet HEAD -- || [ -n "$(git ls-files --others --exclude-standard)" ]; then
                log "Local changes detected, committing and pushing changes..."
                git add -A  # Stage all changes, including untracked files
                git commit -m "local changes before update $(date +%Y%m%d_%H%M%S)"
                # Try to push changes
                if git push origin master; then
                    success "Successfully pushed local changes"
                else
                    warn "Could not push changes. Will create a backup branch"
                    local backup_branch="backup_$(date +%Y%m%d_%H%M%S)"
                    git branch "$backup_branch"
                    log "Created backup branch: $backup_branch"
                fi
            else
                log "No local changes detected"
            fi
            # Update from remote
            git pull --rebase || error "Failed to update from remote"
        }) || error "Failed to update devenv repository"
    fi

    # Run Ansible playbook
    log "Running Ansible playbook..."
    cd ~/git/devenv
    ansible-playbook main.yml || error "Failed to run Ansible playbook"

    success "Setup completed successfully!"
    success "Your development environment is ready to use."
}

# Run main function
main
