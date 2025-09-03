# Ansible Role: Coolify

## Description
Ansible role to deploy and configure Coolify - an open-source, self-hosting PaaS (Platform as a Service) that provides a streamlined way to deploy and manage applications, databases, and services in a homelab or production environment.

## Features
- Docker-based installation
- Automated setup and configuration
- Health checking and verification
- Proper firewall configuration
- Persistent data storage

## Requirements
- Ansible 2.10 or higher
- Linux host with systemd
- Docker and Docker Compose

## Role Variables
All variables are defined in `defaults/main.yml`. Key variables include:

| Variable | Description | Default |
|----------|-------------|---------|
| `coolify_install_dir` | Installation directory | `/opt/coolify` |
| `coolify_ui_port` | UI port | `3000` |
| `coolify_api_port` | API port | `8000` |
| `coolify_data_dir` | Data directory | `{{ coolify_install_dir }}/data` |
| `coolify_network_name` | Docker network name | `coolify` |
| `coolify_domain` | Domain name | `coolify.{{ ansible_hostname }}` |
| `verification_retries` | Number of verification retries | `10` |
| `verification_delay` | Delay between retries (seconds) | `30` |

## Dependencies
- Docker
- Docker Compose

## Example Playbook
```yaml
- hosts: homelab_server
  become: true
  vars:
    coolify_install_dir: "/opt/coolify"
    coolify_ui_port: 3000
    coolify_api_port: 8000
    coolify_domain: "coolify.homelab.local"
  
  roles:
    - role: coolify
```

## Post-Installation
After installation, Coolify will be accessible at `http://your-server-ip:3000`. Follow these steps:
1. Create an admin account
2. Configure your resources and environments
3. Deploy your first application

## Troubleshooting
- Check logs with `docker logs coolify`
- Verify container health with `docker ps`
- Ensure firewall allows traffic on configured ports

## License
MIT

## Author Information
Created for Homelab deployment by l3ocifer
