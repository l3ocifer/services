#!/bin/bash

# Migrate from Docker deployment to Ansible deployment
# This script helps transition from containerized services to local service installations

set -e

echo "🔄 Migrating from Docker to Ansible deployment..."

# Check if we're in the right directory
if [ ! -d "ansible" ] || [ ! -d "docker" ]; then
    echo "❌ Error: This script must be run from the services directory"
    echo "   Expected structure: services/{ansible,docker}/"
    exit 1
fi

# Backup current Docker configuration
echo "📦 Creating backup of Docker configuration..."
BACKUP_DIR="backup-docker-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r docker/ "$BACKUP_DIR/"
echo "✅ Backup created: $BACKUP_DIR"

# Check Ansible prerequisites
echo "🔧 Checking Ansible prerequisites..."
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible is not installed. Please install Ansible first."
    exit 1
fi

if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Ansible Playbook is not installed. Please install Ansible first."
    exit 1
fi

# Stop Docker services
echo "🛑 Stopping Docker services..."
cd docker
if [ -f "docker-compose.yml" ]; then
    echo "   Stopping Docker containers..."
    docker-compose down
    echo "✅ Docker services stopped"
else
    echo "⚠️  No docker-compose.yml found, skipping Docker stop"
fi
cd ..

# Install Ansible dependencies
echo "📦 Installing Ansible dependencies..."
cd ansible
if [ -f "requirements.yml" ]; then
    ansible-galaxy install -r requirements.yml
    echo "✅ Ansible dependencies installed"
else
    echo "⚠️  No requirements.yml found, skipping dependency installation"
fi

# Validate inventory
echo "📋 Validating Ansible inventory..."
if [ -d "inventory" ]; then
    echo "   Inventory directory found"
    if [ -f "inventory/hosts.yml" ] || [ -f "inventory/homelab.ini" ]; then
        echo "✅ Inventory files found"
    else
        echo "⚠️  No inventory files found. Please configure your inventory."
    fi
else
    echo "❌ No inventory directory found. Please create your inventory."
    exit 1
fi

# Run Ansible playbook
echo "🚀 Running Ansible deployment..."
if [ -f "site.yml" ]; then
    echo "   Running main playbook..."
    ansible-playbook site.yml --check
    echo ""
    echo "✅ Ansible deployment check completed successfully!"
    echo "   To apply changes, run: ansible-playbook site.yml"
else
    echo "❌ No site.yml found in ansible directory"
    exit 1
fi
cd ..

echo "✅ Migration to Ansible deployment completed!"
echo ""
echo "📋 Next steps:"
echo "   1. Review and update ansible/inventory/ with your host configuration"
echo "   2. Review ansible/group_vars/ for your environment settings"
echo "   3. Run 'ansible-playbook site.yml' to apply the deployment"
echo "   4. Your Docker configuration is backed up in: $BACKUP_DIR"
echo ""
echo "🔍 To check deployment status:"
echo "   cd ansible && ansible-playbook site.yml --tags verify"
echo ""
echo "📚 For more information, see docs/ansible-deployment.md"
