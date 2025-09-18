#!/bin/bash

# Cloudflare Tunnels + Route53 Setup Script
# This script sets up Cloudflare Tunnels with Route53 domain management

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLOUDFLARE_EMAIL="Lpasko01@gmail.com"
CLOUDFLARE_API_TOKEN="ZPovc0yXoXFiCek5Bd8VBTu-7XSWWhVM5iSomtHm"
DOMAIN="leopaska.xyz"
TUNNEL_NAME="homelab-tunnel"
CONFIG_DIR="/home/l3o/git/homelab/cloudflare-tunnel"
SERVICES_DIR="/home/l3o/git/homelab/services/docker"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if cloudflared is installed
check_cloudflared() {
    if ! command -v cloudflared &> /dev/null; then
        print_warning "cloudflared not found. Installing..."
        install_cloudflared
    else
        print_status "cloudflared is already installed"
    fi
}

# Function to install cloudflared
install_cloudflared() {
    print_header "Installing cloudflared"
    
    # Download and install cloudflared
    wget -O cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
    
    print_status "cloudflared installed successfully"
}

# Function to create tunnel
create_tunnel() {
    print_header "Creating Cloudflare Tunnel"
    
    # Create tunnel
    cloudflared tunnel create "$TUNNEL_NAME" --config "$CONFIG_DIR/config.yml"
    
    # Get tunnel ID
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
    
    print_status "Tunnel created with ID: $TUNNEL_ID"
    echo "TUNNEL_ID=$TUNNEL_ID" > "$CONFIG_DIR/tunnel-id.txt"
}

# Function to create tunnel configuration
create_tunnel_config() {
    print_header "Creating Tunnel Configuration"
    
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_DIR/config.yml" << EOF
tunnel: $TUNNEL_NAME
credentials-file: $CONFIG_DIR/credentials.json

# Ingress rules for your services
ingress:
  # Main homelab dashboard
  - hostname: homelab.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: homelab.$DOMAIN

  # Services overview
  - hostname: services.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: services.$DOMAIN

  # Admin services (with auth)
  - hostname: admin.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: admin.$DOMAIN

  - hostname: coolify.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: coolify.$DOMAIN

  - hostname: grafana.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: grafana.$DOMAIN

  - hostname: logs.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: logs.$DOMAIN

  - hostname: automation.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: automation.$DOMAIN

  - hostname: workflow.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: workflow.$DOMAIN

  - hostname: tracing.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: tracing.$DOMAIN

  - hostname: postiz.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: postiz.$DOMAIN

  - hostname: mail.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: mail.$DOMAIN

  - hostname: queue.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: queue.$DOMAIN

  - hostname: dbadmin.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: dbadmin.$DOMAIN

  # Public services (no auth)
  - hostname: media.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: media.$DOMAIN

  - hostname: home.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: home.$DOMAIN

  - hostname: discover.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: discover.$DOMAIN

  - hostname: stream.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: stream.$DOMAIN

  - hostname: hyvapaska.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: hyvapaska.$DOMAIN

  - hostname: chat.$DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: chat.$DOMAIN

  # Catch-all rule (must be last)
  - service: http_status:404
EOF

    print_status "Tunnel configuration created at $CONFIG_DIR/config.yml"
}

# Function to create systemd service
create_systemd_service() {
    print_header "Creating Systemd Service"
    
    local service_file="/etc/systemd/system/cloudflare-tunnel.service"
    
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target
Wants=network.target

[Service]
Type=simple
User=l3o
Group=l3o
WorkingDirectory=$CONFIG_DIR
ExecStart=/usr/local/bin/cloudflared tunnel --config $CONFIG_DIR/config.yml run
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    print_status "Systemd service created at $service_file"
}

# Function to create Route53 update script
create_route53_script() {
    print_header "Creating Route53 Update Script"
    
    local script_file="$CONFIG_DIR/update-route53.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash

# Route53 Update Script for Cloudflare Tunnels
# This script updates Route53 records to point to Cloudflare

# Configuration
DOMAIN="leopaska.xyz"
HOSTED_ZONE_ID="your-hosted-zone-id"
AWS_PROFILE="default"
AWS_REGION="us-east-1"

# Subdomains to update
SUBDOMAINS=(
    "homelab"
    "services"
    "admin"
    "coolify"
    "grafana"
    "media"
    "home"
    "logs"
    "automation"
    "workflow"
    "tracing"
    "discover"
    "stream"
    "hyvapaska"
    "chat"
    "postiz"
    "mail"
    "queue"
    "dbadmin"
)

# Function to get Cloudflare IPs
get_cloudflare_ips() {
    # Cloudflare IP ranges (these are the main ones, you might want to get the full list)
    echo "173.245.48.0/20"
    echo "103.21.244.0/22"
    echo "103.22.200.0/22"
    echo "103.31.4.0/22"
    echo "141.101.64.0/18"
    echo "108.162.192.0/18"
    echo "190.93.240.0/20"
    echo "188.114.96.0/20"
    echo "197.234.240.0/22"
    echo "198.41.128.0/17"
    echo "162.158.0.0/15"
    echo "104.16.0.0/13"
    echo "104.24.0.0/14"
    echo "172.64.0.0/13"
    echo "131.0.72.0/22"
}

# Function to update Route53 record
update_route53_record() {
    local subdomain="$1"
    local record_name="${subdomain}.${DOMAIN}"
    
    # Get Cloudflare IPs
    local cloudflare_ips=($(get_cloudflare_ips))
    
    # Create the change batch
    local change_batch=$(cat <<EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "${record_name}",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "173.245.48.1"
                    }
                ]
            }
        }
    ]
}
EOF
)
    
    # Apply the change
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --change-batch "$change_batch" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION"
    
    echo "Updated ${record_name} to point to Cloudflare"
}

# Main execution
main() {
    echo "Updating Route53 records to point to Cloudflare..."
    
    for subdomain in "${SUBDOMAINS[@]}"; do
        update_route53_record "$subdomain"
        sleep 1  # Rate limiting
    done
    
    echo "Route53 update completed!"
}

# Run the script
main "$@"
EOF

    chmod +x "$script_file"
    print_status "Route53 update script created at $script_file"
}

# Function to display setup instructions
display_setup_instructions() {
    print_header "Setup Instructions"
    
    echo "1. Get your Cloudflare API token:"
    echo "   - Go to https://dash.cloudflare.com/profile/api-tokens"
    echo "   - Create a token with Zone:Edit permissions"
    echo "   - Update the CLOUDFLARE_API_TOKEN variable in this script"
    echo ""
    echo "2. Update your domain:"
    echo "   - Change 'yourdomain.com' to your actual domain"
    echo "   - Update the HOSTED_ZONE_ID in the Route53 script"
    echo ""
    echo "3. Run the setup:"
    echo "   ./setup.sh"
    echo ""
    echo "4. Start the tunnel:"
    echo "   sudo systemctl enable cloudflare-tunnel.service"
    echo "   sudo systemctl start cloudflare-tunnel.service"
    echo ""
    echo "5. Update Route53 records:"
    echo "   ./update-route53.sh"
    echo ""
    echo "6. Configure Cloudflare security settings:"
    echo "   - Go to your domain in Cloudflare dashboard"
    echo "   - Enable security features (WAF, Bot Fight Mode, etc.)"
    echo "   - Configure SSL/TLS settings"
}

# Main execution
main() {
    print_header "Cloudflare Tunnels + Route53 Setup"
    
    # Check if cloudflared is installed
    check_cloudflared
    
    # Create tunnel configuration
    create_tunnel_config
    
    # Create systemd service
    create_systemd_service
    
    # Create Route53 update script
    create_route53_script
    
    # Display setup instructions
    display_setup_instructions
    
    print_status "Setup completed! Please follow the instructions above to complete the configuration."
}

# Run the script
main "$@"

