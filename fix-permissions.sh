#!/bin/bash

################################################################################
# Homelab Permission Fix Script
#
# This script fixes permission issues on existing installations
# Run this if you encounter permission errors with any services
#
# Usage: sudo ./fix-permissions.sh [username]
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the actual user
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
elif [ -n "$1" ]; then
    ACTUAL_USER="$1"
else
    echo -e "${RED}Error: This script must be run with sudo${NC}"
    echo "Usage: sudo ./fix-permissions.sh [username]"
    exit 1
fi

# Get user's UID and GID
USER_UID=$(id -u "$ACTUAL_USER")
USER_GID=$(id -g "$ACTUAL_USER")

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Homelab - Permission Fix Script                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}User:${NC} $ACTUAL_USER (UID: $USER_UID, GID: $USER_GID)"
echo -e "${GREEN}Project Directory:${NC} $SCRIPT_DIR"
echo ""

# Ask if services should be stopped
read -p "Stop all services before fixing permissions? (recommended) [Y/n]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Stopping services...${NC}"
    cd "$SCRIPT_DIR"
    docker compose down
    echo -e "${GREEN}✓${NC} Services stopped"
fi

echo ""
echo -e "${BLUE}Fixing Data Directory Permissions...${NC}"
echo ""

# Function to fix directory permissions
fix_data_dir() {
    local service=$1
    local uid=$2
    local gid=$3
    local description=$4

    local dir="$SCRIPT_DIR/$service/data"

    if [ -d "$dir" ]; then
        echo -e "${YELLOW}Fixing:${NC} $service/data/ → $uid:$gid ($description)"
        chown -R "$uid:$gid" "$dir"
        chmod -R 755 "$dir"
        echo -e "${GREEN}✓${NC} Fixed"
    else
        echo -e "${BLUE}Creating:${NC} $service/data/ → $uid:$gid"
        mkdir -p "$dir"
        chown -R "$uid:$gid" "$dir"
        chmod -R 755 "$dir"
        echo -e "${GREEN}✓${NC} Created"
    fi
}

# Grafana - UID 472
fix_data_dir "grafana" "472" "472" "Grafana user"

# Prometheus - UID 65534 (nobody)
fix_data_dir "prometheus" "65534" "65534" "Nobody user"

# Loki - UID 10001
fix_data_dir "loki" "10001" "10001" "Loki user"

# Portainer - runs as root but use user ownership for easier management
fix_data_dir "portainer" "$USER_UID" "$USER_GID" "User ownership"

# Jellyfin - uses PUID/PGID
for dir in config cache; do
    full_dir="$SCRIPT_DIR/jellyfin/$dir"
    if [ -d "$full_dir" ]; then
        echo -e "${YELLOW}Fixing:${NC} jellyfin/$dir/ → $USER_UID:$USER_GID"
        chown -R "$USER_UID:$USER_GID" "$full_dir"
        chmod -R 755 "$full_dir"
        echo -e "${GREEN}✓${NC} Fixed"
    else
        echo -e "${BLUE}Creating:${NC} jellyfin/$dir/"
        mkdir -p "$full_dir"
        chown -R "$USER_UID:$USER_GID" "$full_dir"
        chmod -R 755 "$full_dir"
        echo -e "${GREEN}✓${NC} Created"
    fi
done

# Nginx Proxy Manager
for dir in data letsencrypt; do
    full_dir="$SCRIPT_DIR/nginx-proxy-manager/$dir"
    if [ -d "$full_dir" ]; then
        echo -e "${YELLOW}Fixing:${NC} nginx-proxy-manager/$dir/ → 755 permissions"
        chmod -R 755 "$full_dir"
        echo -e "${GREEN}✓${NC} Fixed"
    else
        echo -e "${BLUE}Creating:${NC} nginx-proxy-manager/$dir/"
        mkdir -p "$full_dir"
        chmod -R 755 "$full_dir"
        echo -e "${GREEN}✓${NC} Created"
    fi
done

# ntopng
if [ -d "$SCRIPT_DIR/ntopng/data" ]; then
    echo -e "${YELLOW}Fixing:${NC} ntopng/data/ → 755 permissions"
    chmod -R 755 "$SCRIPT_DIR/ntopng/data"
    echo -e "${GREEN}✓${NC} Fixed"
fi

# OTEL Collector
if [ -d "$SCRIPT_DIR/otel-collector/data" ]; then
    echo -e "${YELLOW}Fixing:${NC} otel-collector/data/ → $USER_UID:$USER_GID"
    chown -R "$USER_UID:$USER_GID" "$SCRIPT_DIR/otel-collector/data"
    chmod -R 755 "$SCRIPT_DIR/otel-collector/data"
    echo -e "${GREEN}✓${NC} Fixed"
fi

# NVIDIA GPU Exporter
if [ -d "$SCRIPT_DIR/nvidia-gpu-exporter/data" ]; then
    echo -e "${YELLOW}Fixing:${NC} nvidia-gpu-exporter/data/ → $USER_UID:$USER_GID"
    chown -R "$USER_UID:$USER_GID" "$SCRIPT_DIR/nvidia-gpu-exporter/data"
    chmod -R 755 "$SCRIPT_DIR/nvidia-gpu-exporter/data"
    echo -e "${GREEN}✓${NC} Fixed"
fi

echo ""
echo -e "${BLUE}Fixing Configuration Directory Permissions...${NC}"
echo ""

# Fix all config directories
for service_dir in "$SCRIPT_DIR"/*/; do
    if [ -d "${service_dir}config" ]; then
        service_name=$(basename "$service_dir")
        echo -e "${YELLOW}Fixing:${NC} $service_name/config/ → $USER_UID:$USER_GID"
        chown -R "$USER_UID:$USER_GID" "${service_dir}config"
        chmod -R 755 "${service_dir}config"
        echo -e "${GREEN}✓${NC} Fixed"
    fi
done

# Fix provisioning directories (Grafana)
if [ -d "$SCRIPT_DIR/grafana/provisioning" ]; then
    echo -e "${YELLOW}Fixing:${NC} grafana/provisioning/ → $USER_UID:$USER_GID"
    chown -R "$USER_UID:$USER_GID" "$SCRIPT_DIR/grafana/provisioning"
    chmod -R 755 "$SCRIPT_DIR/grafana/provisioning"
    echo -e "${GREEN}✓${NC} Fixed"
fi

echo ""
echo -e "${GREEN}✓ All permissions fixed!${NC}"
echo ""
echo -e "${BLUE}You can now start the services:${NC}"
echo "   cd $SCRIPT_DIR"
echo "   docker compose up -d"
echo ""
echo -e "${BLUE}Check logs if issues persist:${NC}"
echo "   docker compose logs -f [service-name]"
