#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check Python dependencies
check_python_deps() {
    if ! python3 -c "import boto3, botocore" 2>/dev/null; then
        echo -e "\n${YELLOW}Warning: Required Python packages (boto3, botocore) are missing${NC}"
        
        # Check if uv is installed
        if ! command -v uv &> /dev/null; then
            echo "Installing uv package installer..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
        fi
        
        # Create venv if it doesn't exist
        VENV_DIR="$GIT_ROOT/.venv"
        if [ ! -d "$VENV_DIR" ]; then
            echo "Creating virtual environment..."
            python3 -m venv "$VENV_DIR"
        fi
        
        echo "Installing required packages..."
        source "$VENV_DIR/bin/activate"
        uv pip install boto3 botocore
        
        # Verify installation
        if ! python3 -c "import boto3, botocore" 2>/dev/null; then
            echo "Failed to install required dependencies"
            exit 1
        fi
    fi
}

# Directory setup - use git root directory
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Error: Not in a git repository"
    exit 1
fi

playbooks_dir="$GIT_ROOT/playbooks"
roles_dir="$GIT_ROOT/roles"
config_file="$GIT_ROOT/.playbook-runner.conf"

# Load last run configuration if exists
if [ -f "$config_file" ]; then
    source "$config_file"
fi

# Scan playbooks directory
playbook_names=()
playbook_paths=()

# Get relative path in a portable way
get_relative_path() {
    local path=$1
    local base=$2
    echo "${path#$base/}"
}

# Load playbooks dynamically
while IFS= read -r -d '' playbook; do
    rel_path=$(get_relative_path "$playbook" "$GIT_ROOT")
    playbook_names+=("$rel_path")
    playbook_paths+=("$playbook")
done < <(find "$playbooks_dir" -maxdepth 1 -name "*.yml" -print0 | sort -z)

# Environment options
environments=("dev" "test" "prod" "cleanup")

# Print header
echo -e "${BLUE}=== Ansible Playbook Runner ===${NC}"

# List available playbooks
echo -e "\n${GREEN}Available Playbooks:${NC}"
if [ ${#playbook_names[@]} -eq 0 ]; then
    echo "No playbooks found in $playbooks_dir"
    exit 1
fi

for i in "${!playbook_names[@]}"; do
    echo "$((i+1))) ${playbook_names[$i]}"
done

# Get playbook selection with default
default_playbook=${LAST_PLAYBOOK:-1}
read -p "Select playbook number [${default_playbook}]: " playbook_num
playbook_num=${playbook_num:-$default_playbook}
playbook_index=$((playbook_num-1))

if [ -z "${playbook_names[$playbook_index]}" ]; then
    echo "Invalid playbook selection"
    exit 1
fi

# List environment options
echo -e "\n${GREEN}Environment:${NC}"
for i in "${!environments[@]}"; do
    case ${environments[$i]} in
        "dev")   echo -e "$((i+1))) ${YELLOW}dev${NC}   - Development environment (no cleanup)" ;;
        "test")  echo -e "$((i+1))) ${YELLOW}test${NC}  - Test environment (with cleanup)" ;;
        "prod")  echo -e "$((i+1))) ${YELLOW}prod${NC}  - Production environment (with load balancer)" ;;
        "cleanup") echo -e "$((i+1))) ${YELLOW}cleanup${NC} - Remove all AWS resources" ;;
    esac
done

# Get environment selection with default
default_env=${LAST_ENV:-1}
read -p "Select environment [1-4/${environments[*]}] [${default_env}]: " environment
environment=${environment:-$default_env}

# Convert numeric input to environment name
if [[ "$environment" =~ ^[0-9]+$ ]]; then
    env_index=$((environment-1))
    if [ "$env_index" -ge 0 ] && [ "$env_index" -lt ${#environments[@]} ]; then
        environment="${environments[$env_index]}"
    fi
fi

# Validate environment
if [[ ! " ${environments[@]} " =~ " ${environment} " ]]; then
    echo "Invalid environment selection"
    exit 1
fi

# Save current selections as defaults
cat > "$config_file" << EOF
LAST_PLAYBOOK=$playbook_num
LAST_ENV=$environment
EOF

# Cleanup function for virtual environment
cleanup_venv() {
    if [ -n "$VIRTUAL_ENV" ]; then
        deactivate 2>/dev/null || true
    fi
}

# Set trap for cleanup
trap cleanup_venv EXIT

# Handle cleanup mode
if [ "${environment}" = "cleanup" ]; then
    cd "$GIT_ROOT"
    echo -e "\n${BLUE}Running cleanup tasks...${NC}"
    check_python_deps
    VENV_DIR="$GIT_ROOT/.venv"
    source "$VENV_DIR/bin/activate"
    ANSIBLE_ROLES_PATH="$roles_dir" PYTHONPATH="$VENV_DIR/lib/python*/site-packages" ansible-playbook "${playbook_paths[$playbook_index]}" \
        -e "cleanup_enabled=true" \
        -e "force_cleanup=true" \
        -e "aws_region=${AWS_REGION:-us-east-1}" \
        -i localhost, \
        -c local
    exit $?
fi

# Get deployment type
echo -e "\n${GREEN}Target Type:${NC}"
echo "1) alef"
echo "2) legion"

# Get deployment type selection with default
default_type=${LAST_TYPE:-1}
read -p "Select target type [${default_type}]: " type_num
type_num=${type_num:-$default_type}

case $type_num in
    1) deployment_type="alef" ;;
    2) deployment_type="legion" ;;
    *) echo "Invalid target type selection"; exit 1 ;;
esac

# Get instance count with default
echo -e "\n${GREEN}Instance Configuration:${NC}"
default_count=${LAST_COUNT:-1}
read -p "Number of instances to create [${default_count}]: " instance_count
instance_count=${instance_count:-$default_count}

if ! [[ "$instance_count" =~ ^[0-9]+$ ]] || [ "$instance_count" -lt 1 ]; then
    echo "Invalid instance count. Must be a positive number."
    exit 1
fi

# Additional options with defaults
echo -e "\n${GREEN}Additional Options:${NC}"
default_cleanup=${LAST_CLEANUP:-"N"}
read -p "Run cleanup? (y/N) [${default_cleanup}]: " cleanup_requested
cleanup_requested=${cleanup_requested:-$default_cleanup}

# Update config file with all selections
cat > "$config_file" << EOF
LAST_PLAYBOOK=$playbook_num
LAST_ENV=$environment
LAST_TYPE=$type_num
LAST_COUNT=$instance_count
LAST_CLEANUP=$cleanup_requested
EOF

# Convert responses to ansible variables
cleanup_requested_value="false"
if [[ $cleanup_requested =~ ^[Yy]$ ]]; then
    cleanup_requested_value="true"
fi

# Execute playbook from git root
cd "$GIT_ROOT"
echo -e "\n${BLUE}Running playbook with selected options...${NC}"
check_python_deps
VENV_DIR="$GIT_ROOT/.venv"
source "$VENV_DIR/bin/activate"
ANSIBLE_ROLES_PATH="$roles_dir" PYTHONPATH="$VENV_DIR/lib/python*/site-packages" ansible-playbook "${playbook_paths[$playbook_index]}" \
    -e "target_env=${environment}" \
    -e "deployment_type=${deployment_type}" \
    -e "instance_count=${instance_count}" \
    -e "cleanup_requested=${cleanup_requested_value}" \
    -e "aws_region=${AWS_REGION:-us-east-1}" \
    -i localhost, \
    -c local
deactivate 