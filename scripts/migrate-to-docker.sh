#!/bin/bash

# Migrate from Ansible deployment to Docker deployment
# This script helps transition from local service installations to containerized services

set -e

echo "🔄 Migrating from Ansible to Docker deployment..."

# Check if we're in the right directory
if [ ! -d "ansible" ] || [ ! -d "docker" ]; then
    echo "❌ Error: This script must be run from the services directory"
    echo "   Expected structure: services/{ansible,docker}/"
    exit 1
fi

# Backup current Ansible configuration
echo "📦 Creating backup of Ansible configuration..."
BACKUP_DIR="backup-ansible-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r ansible/ "$BACKUP_DIR/"
echo "✅ Backup created: $BACKUP_DIR"

# Check Docker prerequisites
echo "🐳 Checking Docker prerequisites..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Copy environment template
echo "⚙️  Setting up Docker environment..."
if [ ! -f "docker/.env" ]; then
    if [ -f "docker/.env.example" ]; then
        cp docker/.env.example docker/.env
        echo "✅ Created .env file from template"
        echo "⚠️  Please edit docker/.env with your configuration before starting services"
    else
        echo "❌ No .env.example found in docker directory"
        exit 1
    fi
fi

# Stop any running Ansible-managed services
echo "🛑 Stopping Ansible-managed services..."
cd ansible
if [ -f "site.yml" ]; then
    echo "   Running Ansible playbook to stop services..."
    ansible-playbook site.yml --tags "stop" --check 2>/dev/null || echo "   (No stop tasks defined or services not running)"
fi
cd ..

# Start Docker services
echo "🚀 Starting Docker services..."
cd docker
docker-compose up -d
cd ..

echo "✅ Migration to Docker deployment completed!"
echo ""
echo "📋 Next steps:"
echo "   1. Edit docker/.env with your configuration"
echo "   2. Review docker/docker-compose.yml for any customizations"
echo "   3. Access services via the URLs defined in the Docker setup"
echo "   4. Your Ansible configuration is backed up in: $BACKUP_DIR"
echo ""
echo "🔍 To check service status:"
echo "   cd docker && docker-compose ps"
echo ""
echo "📚 For more information, see docs/docker-deployment.md"
