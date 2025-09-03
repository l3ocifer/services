#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function is_arm_mac() {
    [[ "$(uname -m)" == "arm64" ]] && [[ "$(uname)" == "Darwin" ]]
}

function is_macos() {
    [[ "$(uname)" == "Darwin" ]]
}

function install_dependencies() {
    echo "Installing dependencies..."
    
    if is_macos; then
        if ! command -v brew >/dev/null 2>&1; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        if ! command -v ansible >/dev/null 2>&1; then
            echo "Installing Ansible..."
            brew install ansible
        fi
        
        if ! command -v syncthing >/dev/null 2>&1; then
            echo "Installing Syncthing..."
            brew install syncthing
        fi
    else
        if ! command -v ansible >/dev/null 2>&1; then
            echo "Installing Ansible..."
            sudo apt-get update
            sudo apt-get install -y ansible
        fi
    fi
    
    # Install Ansible collections
    ansible-galaxy collection install community.general
}

function run_tests() {
    echo "Running Molecule tests..."
    if ! command -v molecule &> /dev/null; then
        pip install molecule molecule-docker ansible-lint yamllint docker
    fi

    echo "Starting Colima if not running..."
    if ! colima status &> /dev/null; then
        colima start
    fi

    export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
    molecule test
}

# Main execution
install_dependencies
run_tests

echo -e "${GREEN}✓ All tests completed${NC}"
