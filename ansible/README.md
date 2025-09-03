# Homelab DevEnv

A comprehensive Ansible-based homelab setup with automated role generation, verification, and deployment capabilities.

## Architecture

### Core Components

- **Infrastructure Roles**: Network, security, and core services
- **Monitoring Stack**: Prometheus, Grafana, Loki for comprehensive monitoring
- **Storage Solutions**: Syncthing, Restic for data management
- **Security Layer**: Fail2ban, UFW, custom iptables configuration
- **Development Tools**: Rustdesk, Rustpad, Coolify
- **AI Services**: Librechat, Ollama, Mistral.rs (High-resource nodes only)

### Resource Tiers

#### High Resource Node (Desktop Server)
- **Hardware**: 55GB RAM, Multiple TB Storage
- **Services**:
  - AI Services (Ollama, Librechat)
  - Primary Monitoring Stack
  - Video Conferencing (Jitsi)
  - Primary DNS Controller

#### Raspberry Pi Cluster (30 nodes)
- **Hardware per Node**: 1GB RAM, 16-64GB Storage
- **Distributed Services**:
  - DNS Servers (5 nodes)
  - Monitoring Collectors (5 nodes)
  - Storage Nodes (4 nodes)
  - Edge Nodes (3 nodes)
  - General Purpose/Failover (13 nodes)

### AWS Integration

The homelab integrates with AWS Route53 for domain management using existing AWS profiles:

#### AWS Authentication
- Uses existing AWS profiles and credentials
- Supports multiple AWS accounts via profile switching
- Environment variables for credentials:
  - `AWS_PROFILE`: AWS profile name (defaults to 'default')
  - `AWS_ACCESS_KEY_ID`: AWS access key
  - `AWS_SECRET_ACCESS_KEY`: AWS secret key
  - `AWS_SESSION_TOKEN`: Optional session token

#### Route53 Configuration
- Primary zone controller on main server
- Secondary DNS servers on edge nodes
- Support for multiple Route53 zones across accounts
- Automated DNS updates via AWS API

#### Running with Route53
```bash
# Example: Running playbook with Route53 zone ID
ansible-playbook site.yml -e "route53_zone_id=Z0123456789ABCDEF"

# Multiple zones example
ansible-playbook site.yml -e '{
  "route53_zones": {
    "homelab.internal": "Z0123456789ABCDEF",
    "prod.example.com": "Z9876543210FEDCBA"
  }
}'
```

### Coolify Integration

Coolify serves as the primary deployment and management platform:
- Environment variables required:
  - `COOLIFY_API_KEY`: API key for Coolify access
  - `COOLIFY_DOMAIN`: Domain where Coolify is hosted
- Features:
  - Centralized dashboard for all services
  - Automated deployments
  - Resource monitoring
  - SSL certificate management

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/devenv.git
   cd devenv
   ```

2. Install dependencies:
   ```bash
   ansible-galaxy install -r requirements.yml
   ```

3. Configure your inventory in `inventory/`:
   ```yaml
   all:
     children:
       high_resource:
         hosts:
           alef:
             ansible_host: 192.168.1.10
       medium_resource:
         hosts:
           bet:
             ansible_host: 192.168.1.11
       low_resource:
         hosts:
           gimel:
             ansible_host: 192.168.1.12
   ```

4. Run the playbook:
   ```bash
   ansible-playbook site.yml
   ```

## Role Management

### Role Structure
```
roles/
├── service-template/          # Base template for all roles
│   ├── defaults/
│   │   └── main.yml         # Default variables
│   ├── handlers/
│   │   └── main.yml         # Service handlers
│   ├── tasks/
│   │   └── main.yml         # Tasks with integrated verification
│   └── templates/
│       └── config.yml.j2    # Service configuration template
└── [service_name]/           # Generated service roles
```

### Creating New Roles

1. Add role definition to `scripts/generate_roles.sh`:
   ```bash
   ["new_service"]="service description;resource_tier;category"
   ```

2. Run the role generator:
   ```bash
   ./scripts/generate_roles.sh
   ```

3. Customize the generated role:
   - Update `defaults/main.yml` with service-specific variables
   - Modify `tasks/main.yml` for service installation
   - Configure `templates/config.yml.j2` for service configuration

### Integrated Verification

Each role includes automated verification:
- System requirements validation
- Package installation checks
- Service status verification
- Configuration validation
- Port and health endpoint monitoring
- Backup configuration verification

## Configuration

### Group Variables
Located in `group_vars/`:
- `all.yml`: Global variables
- `high_resource.yml`: High-resource node settings
- `medium_resource.yml`: Medium-resource node settings
- `low_resource.yml`: Low-resource node settings

### Host Variables
Located in `host_vars/`:
- Individual host configurations
- Node-specific overrides

## Best Practices

1. **Role Development**:
   - Always use the role generator for consistency
   - Include comprehensive verification steps
   - Document all variables in defaults/main.yml
   - Test on appropriate resource tier

2. **Security**:
   - Use vault for sensitive data
   - Implement least privilege access
   - Regular security role updates
   - Maintain firewall configurations

3. **Monitoring**:
   - Enable health checks where possible
   - Configure appropriate resource limits
   - Set up alerting thresholds
   - Regular backup verification

4. **Maintenance**:
   - Regular role updates
   - Backup verification
   - Security patches
   - Performance monitoring

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add/modify roles using the generator
4. Submit a pull request

## License

MIT

## Author

Created for Homelab deployment
