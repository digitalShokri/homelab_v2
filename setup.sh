#!/bin/bash

################################################################################
# Homelab Setup Script
#
# This script:
# - Installs Docker and Docker Compose v2
# - Configures user groups for Docker access
# - Creates necessary directories with proper permissions
# - Fixes common permission issues
#
# Usage: sudo ./setup.sh [username]
#        If no username provided, uses the user who invoked sudo
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the actual user (not root when using sudo)
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME=$(eval echo ~$SUDO_USER)
elif [ -n "$1" ]; then
    ACTUAL_USER="$1"
    ACTUAL_HOME=$(eval echo ~$1)
else
    echo -e "${RED}Error: This script must be run with sudo${NC}"
    echo "Usage: sudo ./setup.sh [username]"
    exit 1
fi

# Get user's UID and GID
USER_UID=$(id -u "$ACTUAL_USER")
USER_GID=$(id -g "$ACTUAL_USER")

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Homelab Monitoring Stack - Setup Script                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}User:${NC} $ACTUAL_USER (UID: $USER_UID, GID: $USER_GID)"
echo -e "${GREEN}Project Directory:${NC} $SCRIPT_DIR"
echo ""

################################################################################
# Function: Print section header
################################################################################
print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

################################################################################
# Function: Check if command exists
################################################################################
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

################################################################################
# 1. Install Docker
################################################################################
print_section "1. Installing Docker"

if command_exists docker; then
    echo -e "${GREEN}✓${NC} Docker is already installed"
    docker --version
else
    echo -e "${YELLOW}Installing Docker...${NC}"

    # Update package index
    apt-get update

    # Install prerequisites
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo -e "${GREEN}✓${NC} Docker installed successfully"
    docker --version
fi

################################################################################
# 2. Configure User Groups
################################################################################
print_section "2. Configuring User Groups"

# Create docker group if it doesn't exist
if ! getent group docker > /dev/null 2>&1; then
    echo -e "${YELLOW}Creating docker group...${NC}"
    groupadd docker
    echo -e "${GREEN}✓${NC} Docker group created"
else
    echo -e "${GREEN}✓${NC} Docker group already exists"
fi

# Add user to docker group
if groups "$ACTUAL_USER" | grep -q '\bdocker\b'; then
    echo -e "${GREEN}✓${NC} User $ACTUAL_USER is already in docker group"
else
    echo -e "${YELLOW}Adding $ACTUAL_USER to docker group...${NC}"
    usermod -aG docker "$ACTUAL_USER"
    echo -e "${GREEN}✓${NC} User added to docker group"
    echo -e "${YELLOW}⚠${NC}  You may need to log out and back in for group changes to take effect"
fi

# Start and enable Docker service
systemctl enable docker
systemctl start docker
echo -e "${GREEN}✓${NC} Docker service enabled and started"

################################################################################
# 3. Verify Docker Compose v2
################################################################################
print_section "3. Verifying Docker Compose v2"

if docker compose version >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker Compose v2 is installed"
    docker compose version
else
    echo -e "${RED}✗${NC} Docker Compose v2 not found (should have been installed with Docker)"
    exit 1
fi

################################################################################
# 4. Create .env file if it doesn't exist
################################################################################
print_section "4. Setting up Environment Variables"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}Creating .env file from .env.example...${NC}"
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"

    # Update PUID and PGID
    sed -i "s/^PUID=.*/PUID=$USER_UID/" "$SCRIPT_DIR/.env"
    sed -i "s/^PGID=.*/PGID=$USER_GID/" "$SCRIPT_DIR/.env"

    # Set ownership
    chown "$ACTUAL_USER:$ACTUAL_USER" "$SCRIPT_DIR/.env"

    echo -e "${GREEN}✓${NC} .env file created with UID=$USER_UID and GID=$USER_GID"
    echo -e "${YELLOW}⚠${NC}  Please review and update .env file with your specific settings"
else
    echo -e "${GREEN}✓${NC} .env file already exists"

    # Verify PUID/PGID are set correctly
    if grep -q "^PUID=$USER_UID" "$SCRIPT_DIR/.env" && grep -q "^PGID=$USER_GID" "$SCRIPT_DIR/.env"; then
        echo -e "${GREEN}✓${NC} PUID and PGID are correctly set"
    else
        echo -e "${YELLOW}⚠${NC}  Updating PUID and PGID in .env file..."
        sed -i "s/^PUID=.*/PUID=$USER_UID/" "$SCRIPT_DIR/.env"
        sed -i "s/^PGID=.*/PGID=$USER_GID/" "$SCRIPT_DIR/.env"
        echo -e "${GREEN}✓${NC} Updated to UID=$USER_UID and GID=$USER_GID"
    fi
fi

################################################################################
# 5. Create Data Directories with Proper Permissions
################################################################################
print_section "5. Creating Data Directories"

# Function to create directory with specific ownership
create_data_dir() {
    local service=$1
    local uid=$2
    local gid=$3
    local description=$4

    local dir="$SCRIPT_DIR/$service/data"

    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}Creating:${NC} $service/data/ (owner: $uid:$gid) - $description"
        mkdir -p "$dir"
    else
        echo -e "${GREEN}Exists:${NC} $service/data/ (updating permissions)"
    fi

    chown -R "$uid:$gid" "$dir"
    chmod -R 755 "$dir"
}

# Grafana - runs as UID 472
create_data_dir "grafana" "472" "472" "Grafana default user"

# Prometheus - runs as UID 65534 (nobody)
create_data_dir "prometheus" "65534" "65534" "Prometheus nobody user"

# Loki - runs as UID 10001
create_data_dir "loki" "10001" "10001" "Loki default user"

# Portainer - runs as root, but we'll use user permissions for easier management
create_data_dir "portainer" "$USER_UID" "$USER_GID" "User-owned (Portainer runs as root)"

# Nginx Proxy Manager - runs as root, use user permissions
for dir in data letsencrypt; do
    local full_dir="$SCRIPT_DIR/nginx-proxy-manager/$dir"
    if [ ! -d "$full_dir" ]; then
        echo -e "${YELLOW}Creating:${NC} nginx-proxy-manager/$dir/ (owner: root)"
        mkdir -p "$full_dir"
    else
        echo -e "${GREEN}Exists:${NC} nginx-proxy-manager/$dir/"
    fi
    # NPM needs to run as root for port binding, but we'll set permissive permissions
    chmod -R 755 "$full_dir"
done

# ntopng - runs as root in host mode
if [ ! -d "$SCRIPT_DIR/ntopng/data" ]; then
    echo -e "${YELLOW}Creating:${NC} ntopng/data/ (owner: root)"
    mkdir -p "$SCRIPT_DIR/ntopng/data"
fi
chmod -R 755 "$SCRIPT_DIR/ntopng/data"

# Jellyfin - uses PUID/PGID from .env
for dir in config cache; do
    local full_dir="$SCRIPT_DIR/jellyfin/$dir"
    if [ ! -d "$full_dir" ]; then
        echo -e "${YELLOW}Creating:${NC} jellyfin/$dir/ (owner: $USER_UID:$USER_GID)"
        mkdir -p "$full_dir"
    else
        echo -e "${GREEN}Exists:${NC} jellyfin/$dir/"
    fi
    chown -R "$USER_UID:$USER_GID" "$full_dir"
    chmod -R 755 "$full_dir"
done

# OTEL Collector - create data directory if needed
if [ ! -d "$SCRIPT_DIR/otel-collector/data" ]; then
    echo -e "${YELLOW}Creating:${NC} otel-collector/data/ (owner: $USER_UID:$USER_GID)"
    mkdir -p "$SCRIPT_DIR/otel-collector/data"
    chown -R "$USER_UID:$USER_GID" "$SCRIPT_DIR/otel-collector/data"
fi

# NVIDIA GPU Exporter - if it exists
if [ -d "$SCRIPT_DIR/nvidia-gpu-exporter" ]; then
    if [ ! -d "$SCRIPT_DIR/nvidia-gpu-exporter/data" ]; then
        echo -e "${YELLOW}Creating:${NC} nvidia-gpu-exporter/data/ (owner: $USER_UID:$USER_GID)"
        mkdir -p "$SCRIPT_DIR/nvidia-gpu-exporter/data"
        chown -R "$USER_UID:$USER_GID" "$SCRIPT_DIR/nvidia-gpu-exporter/data"
    fi
fi

echo -e "${GREEN}✓${NC} All data directories created with proper permissions"

################################################################################
# 6. Fix Config Directory Permissions
################################################################################
print_section "6. Fixing Configuration Directory Permissions"

# Make sure all config directories are readable by containers
for service_dir in "$SCRIPT_DIR"/*/; do
    if [ -d "${service_dir}config" ]; then
        service_name=$(basename "$service_dir")
        echo -e "${GREEN}Fixing:${NC} $service_name/config/"
        chmod -R 755 "${service_dir}config"
        chown -R "$USER_UID:$USER_GID" "${service_dir}config"
    fi
done

echo -e "${GREEN}✓${NC} Configuration directories permissions fixed"

################################################################################
# 7. Docker Socket Permissions
################################################################################
print_section "7. Configuring Docker Socket Permissions"

# Ensure docker.sock has proper permissions
chmod 666 /var/run/docker.sock 2>/dev/null || true
echo -e "${GREEN}✓${NC} Docker socket permissions configured"
echo -e "${YELLOW}⚠${NC}  Note: socket permissions reset on reboot - user should be in docker group"

################################################################################
# 8. Summary and Next Steps
################################################################################
print_section "Setup Complete!"

echo -e "${GREEN}✓${NC} Docker installed and configured"
echo -e "${GREEN}✓${NC} User added to docker group"
echo -e "${GREEN}✓${NC} Data directories created with proper permissions"
echo -e "${GREEN}✓${NC} Configuration directories permissions fixed"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. ${YELLOW}Review and update .env file:${NC}"
echo "   nano $SCRIPT_DIR/.env"
echo ""
echo "2. ${YELLOW}Log out and back in${NC} for group changes to take effect"
echo "   Or run: ${GREEN}newgrp docker${NC}"
echo ""
echo "3. ${YELLOW}Start the stack:${NC}"
echo "   cd $SCRIPT_DIR"
echo "   docker compose up -d"
echo ""
echo "4. ${YELLOW}Check service status:${NC}"
echo "   docker compose ps"
echo "   docker compose logs -f"
echo ""
echo -e "${BLUE}Permission Notes:${NC}"
echo "• Grafana runs as UID 472 (data owned by 472:472)"
echo "• Prometheus runs as UID 65534 (data owned by nobody:nogroup)"
echo "• Loki runs as UID 10001 (data owned by 10001:10001)"
echo "• Jellyfin uses PUID/PGID from .env (currently $USER_UID:$USER_GID)"
echo "• Other services run as root or use host user permissions"
echo ""
echo -e "${YELLOW}If you still encounter permission issues, run:${NC}"
echo "   sudo ./fix-permissions.sh"
echo ""
echo -e "${GREEN}Setup completed successfully!${NC}"
