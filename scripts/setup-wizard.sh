#!/bin/bash
# Homelab Monitoring Setup Wizard
# This script gathers system information and configures the .env file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Homelab Monitoring Setup Wizard${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${GREEN}==>${NC} $1"
}

# Function to get user input with default
get_input() {
    local prompt="$1"
    local default="$2"
    local varname="$3"

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        eval $varname="\${input:-$default}"
    else
        read -p "$prompt: " input
        eval $varname="$input"
    fi
}

# Function to detect system information
detect_system_info() {
    print_section "Detecting System Information"

    # Detect primary network interface
    DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    echo -e "${GREEN}✓${NC} Detected network interface: $DEFAULT_INTERFACE"

    # Detect primary IP address
    DEFAULT_IP=$(ip -4 addr show $DEFAULT_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    echo -e "${GREEN}✓${NC} Detected IP address: $DEFAULT_IP"

    # Detect user/group IDs
    DEFAULT_PUID=$(id -u)
    DEFAULT_PGID=$(id -g)
    echo -e "${GREEN}✓${NC} Detected UID/GID: $DEFAULT_PUID/$DEFAULT_PGID"

    # Detect timezone
    if [ -f /etc/timezone ]; then
        DEFAULT_TZ=$(cat /etc/timezone)
    else
        DEFAULT_TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
    fi
    echo -e "${GREEN}✓${NC} Detected timezone: $DEFAULT_TZ"

    # Check Docker installation
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
        echo -e "${GREEN}✓${NC} Docker installed: $DOCKER_VERSION"
    else
        echo -e "${RED}✗${NC} Docker not found! Please install Docker first."
        exit 1
    fi

    # Check Docker Compose
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version | awk '{print $4}')
        echo -e "${GREEN}✓${NC} Docker Compose installed: $COMPOSE_VERSION"
    else
        echo -e "${RED}✗${NC} Docker Compose not found! Please install Docker Compose V2."
        exit 1
    fi
}

# Function to check for existing .env
check_existing_env() {
    if [ -f "$PROJECT_ROOT/.env" ]; then
        echo -e "${YELLOW}⚠${NC} Found existing .env file"
        read -p "Do you want to overwrite it? (y/N): " overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            echo "Exiting without changes."
            exit 0
        fi
        # Backup existing .env
        cp "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓${NC} Backed up existing .env file"
    fi
}

# Function to find common media directories
find_media_dirs() {
    print_section "Searching for Media Directories"

    # Common media locations
    local media_paths=(
        "/media"
        "/mnt/media"
        "$HOME/Media"
        "$HOME/Videos"
        "$HOME/Music"
        "$HOME/Pictures"
        "/srv/media"
        "/data/media"
    )

    echo "Checking common media locations..."
    for path in "${media_paths[@]}"; do
        if [ -d "$path" ]; then
            echo -e "${GREEN}✓${NC} Found: $path"
        fi
    done
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate directory path
validate_path() {
    local path=$1
    if [ -d "$path" ]; then
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Directory does not exist: $path"
        read -p "Create it? (y/N): " create
        if [[ $create =~ ^[Yy]$ ]]; then
            mkdir -p "$path"
            echo -e "${GREEN}✓${NC} Created directory: $path"
            return 0
        fi
        return 1
    fi
}

# Main setup function
main_setup() {
    # Detect system info
    detect_system_info

    # Check for existing .env
    check_existing_env

    # Network Configuration
    print_section "Network Configuration"

    get_input "Server IP address" "$DEFAULT_IP" SERVER_IP
    while ! validate_ip "$SERVER_IP"; do
        echo -e "${RED}✗${NC} Invalid IP address format"
        get_input "Server IP address" "$DEFAULT_IP" SERVER_IP
    done

    echo ""
    echo "Available network interfaces:"
    ip -br link show | grep -v "lo" | awk '{print "  - " $1}'
    echo ""
    get_input "Network interface for ntopng" "$DEFAULT_INTERFACE" NETWORK_INTERFACE

    # System Configuration
    print_section "System Configuration"

    get_input "User ID (PUID)" "$DEFAULT_PUID" PUID
    get_input "Group ID (PGID)" "$DEFAULT_PGID" PGID
    get_input "Timezone" "$DEFAULT_TZ" TZ

    # Security Configuration
    print_section "Security Configuration"

    get_input "Grafana admin username" "admin" GRAFANA_ADMIN_USER

    # Generate strong password suggestion
    SUGGESTED_PASSWORD=$(openssl rand -base64 16 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*' | fold -w 16 | head -n 1)
    echo -e "${YELLOW}Suggested password:${NC} $SUGGESTED_PASSWORD"
    get_input "Grafana admin password" "$SUGGESTED_PASSWORD" GRAFANA_ADMIN_PASSWORD

    # Prometheus Configuration
    print_section "Prometheus Configuration"

    get_input "Metrics retention period" "15d" PROMETHEUS_RETENTION

    # Loki Configuration
    print_section "Loki Configuration"

    get_input "Log retention period (hours)" "720" LOKI_RETENTION_HOURS

    # ntopng Configuration
    print_section "ntopng Configuration"

    get_input "ntopng HTTP port" "3001" NTOPNG_HTTP_PORT

    # Jellyfin Configuration
    print_section "Jellyfin Configuration"

    read -p "Configure Jellyfin media paths? (y/N): " config_jellyfin

    if [[ $config_jellyfin =~ ^[Yy]$ ]]; then
        find_media_dirs

        get_input "Path to Movies directory" "/media/movies" MEDIA_MOVIES
        get_input "Path to TV Shows directory" "/media/tv" MEDIA_TV
        get_input "Path to Music directory" "/media/music" MEDIA_MUSIC
        get_input "Path to Photos directory" "/media/photos" MEDIA_PHOTOS

        JELLYFIN_PUBLISHED_URL="http://${SERVER_IP}:8096"
    else
        MEDIA_MOVIES="/path/to/movies"
        MEDIA_TV="/path/to/tv"
        MEDIA_MUSIC="/path/to/music"
        MEDIA_PHOTOS="/path/to/photos"
        JELLYFIN_PUBLISHED_URL="http://${SERVER_IP}:8096"
    fi

    # Generate .env file
    print_section "Generating Configuration"

    cat > "$PROJECT_ROOT/.env" << EOF
# Homelab Monitoring Stack - Environment Variables
# Generated by setup-wizard.sh on $(date)

# ============================================
# SYSTEM CONFIGURATION
# ============================================
SERVER_IP=${SERVER_IP}
NETWORK_INTERFACE=${NETWORK_INTERFACE}
PUID=${PUID}
PGID=${PGID}
TZ=${TZ}

# ============================================
# GRAFANA CONFIGURATION
# ============================================
GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}

# ============================================
# PROMETHEUS CONFIGURATION
# ============================================
PROMETHEUS_RETENTION=${PROMETHEUS_RETENTION}

# ============================================
# LOKI CONFIGURATION
# ============================================
LOKI_RETENTION_PERIOD=${LOKI_RETENTION_HOURS}h

# ============================================
# NTOPNG CONFIGURATION
# ============================================
NTOPNG_HTTP_PORT=${NTOPNG_HTTP_PORT}

# ============================================
# JELLYFIN CONFIGURATION
# ============================================
JELLYFIN_PUBLISHED_URL=${JELLYFIN_PUBLISHED_URL}
MEDIA_MOVIES=${MEDIA_MOVIES}
MEDIA_TV=${MEDIA_TV}
MEDIA_MUSIC=${MEDIA_MUSIC}
MEDIA_PHOTOS=${MEDIA_PHOTOS}

# ============================================
# OPENTELEMETRY COLLECTOR
# ============================================
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
EOF

    echo -e "${GREEN}✓${NC} Created .env file"

    # Summary
    print_section "Configuration Summary"

    echo ""
    echo -e "Server IP:           ${BLUE}${SERVER_IP}${NC}"
    echo -e "Network Interface:   ${BLUE}${NETWORK_INTERFACE}${NC}"
    echo -e "Grafana Admin:       ${BLUE}${GRAFANA_ADMIN_USER}${NC}"
    echo -e "Prometheus Retention:${BLUE}${PROMETHEUS_RETENTION}${NC}"
    echo -e "Loki Retention:      ${BLUE}${LOKI_RETENTION_HOURS}h${NC}"
    echo ""

    # Next steps
    print_section "Next Steps"

    echo ""
    echo "1. Review the generated .env file:"
    echo -e "   ${BLUE}nano $PROJECT_ROOT/.env${NC}"
    echo ""
    echo "2. Start the monitoring stack:"
    echo -e "   ${BLUE}cd $PROJECT_ROOT && docker compose up -d${NC}"
    echo ""
    echo "3. Access the landing page:"
    echo -e "   ${BLUE}http://${SERVER_IP}${NC}"
    echo ""
    echo "4. Access Grafana:"
    echo -e "   ${BLUE}http://${SERVER_IP}:3000${NC}"
    echo -e "   Username: ${GRAFANA_ADMIN_USER}"
    echo -e "   Password: (see .env file)"
    echo ""

    # Offer to start services
    read -p "Start services now? (y/N): " start_services

    if [[ $start_services =~ ^[Yy]$ ]]; then
        print_section "Starting Services"
        cd "$PROJECT_ROOT"
        docker compose pull
        docker compose up -d

        echo ""
        echo -e "${GREEN}✓${NC} Services started!"
        echo ""
        echo "Check status with: ${BLUE}docker compose ps${NC}"
        echo "View logs with:    ${BLUE}docker compose logs -f${NC}"
    fi

    echo ""
    echo -e "${GREEN}Setup complete!${NC}"
}

# Run main setup
main_setup
