.PHONY: help setup start stop restart status logs pull update clean backup n8n-enable n8n-disable

# Default target
help:
	@echo "Homelab Monitoring Stack - Available Commands"
	@echo ""
	@echo "Setup & Configuration:"
	@echo "  make setup     - Run interactive setup wizard"
	@echo "  make config    - Edit .env configuration file"
	@echo ""
	@echo "Service Management:"
	@echo "  make start     - Start all services"
	@echo "  make stop      - Stop all services"
	@echo "  make restart   - Restart all services"
	@echo "  make status    - Show service status"
	@echo ""
	@echo "Monitoring:"
	@echo "  make logs      - Follow logs from all services"
	@echo "  make logs-[service] - Follow logs from specific service"
	@echo "                 Example: make logs-grafana"
	@echo ""
	@echo "Maintenance:"
	@echo "  make pull      - Pull latest Docker images"
	@echo "  make update    - Update services (pull + restart)"
	@echo "  make clean     - Remove stopped containers and unused images"
	@echo "  make backup    - Backup configurations and data"
	@echo ""
	@echo "Optional Add-ons (Compose profiles, COMPOSE_PROFILES in .env):"
	@echo "  make n8n-enable  - Enable and start n8n (port 5678)"
	@echo "  make n8n-disable - Stop n8n and disable it (data is kept)"
	@echo ""
	@echo "Quick Access URLs:"
	@echo "  Landing Page: http://localhost or http://YOUR_SERVER_IP"
	@echo "  Grafana:      http://localhost:3002"
	@echo "  Prometheus:   http://localhost:9090"
	@echo "  Portainer:    http://localhost:9000"
	@echo "  n8n (add-on): http://localhost:5678"

# Setup wizard
setup:
	@./scripts/setup-wizard.sh

# Edit configuration
config:
	@if [ ! -f .env ]; then cp .env.example .env; fi
	@$${EDITOR:-nano} .env

# Start services
start:
	@echo "Starting all services..."
	@docker compose up -d
	@echo ""
	@echo "Services started! Check status with: make status"

# Stop services
stop:
	@echo "Stopping all services..."
	@docker compose down
	@echo "Services stopped"

# Restart services
restart:
	@echo "Restarting all services..."
	@docker compose restart
	@echo "Services restarted"

# Show service status
status:
	@docker compose ps

# Follow logs from all services
logs:
	@docker compose logs -f

# Follow logs from specific service (usage: make logs-grafana)
logs-%:
	@docker compose logs -f $*

# Pull latest images
pull:
	@echo "Pulling latest Docker images..."
	@docker compose pull

# Update services (pull + restart)
update: pull
	@echo "Updating services..."
	@docker compose up -d
	@echo ""
	@echo "Update complete! Check status with: make status"

# Clean up
clean:
	@echo "Cleaning up Docker resources..."
	@docker compose down -v
	@docker system prune -f
	@echo "Cleanup complete"

# Backup configurations
# GNU tar options are positional: the excludes apply only to paths after them,
# so n8n/data (workflows + credentials DB) goes first to stay in the archive.
backup:
	@echo "Creating backup..."
	@mkdir -p backups
	@tar czf backups/homelab-backup-$$(date +%Y%m%d-%H%M%S).tar.gz \
		$$( [ -d n8n/data ] && echo n8n/data ) \
		--exclude='*/data' \
		--exclude='*/cache' \
		--exclude='*/lib' \
		*/config/ \
		.env \
		docker-compose.yml \
		*/docker-compose.yml
	@echo "Backup created in backups/ directory"

# Backup with data
backup-full:
	@echo "Creating full backup (including data)..."
	@mkdir -p backups
	@tar czf backups/homelab-full-backup-$$(date +%Y%m%d-%H%M%S).tar.gz \
		. \
		--exclude='./backups' \
		--exclude='./.git'
	@echo "Full backup created in backups/ directory"

# Restore from backup
restore:
	@echo "Available backups:"
	@ls -1 backups/
	@echo ""
	@read -p "Enter backup filename to restore: " backup; \
	tar xzf backups/$$backup

# Optional add-on: n8n (profile "n8n")
# Adds n8n to COMPOSE_PROFILES and creates N8N_ENCRYPTION_KEY if missing.
n8n-enable:
	@[ -f .env ] || { echo "❌ .env not found. Run 'make setup' first"; exit 1; }
	@grep -q '^COMPOSE_PROFILES=' .env || printf '\nCOMPOSE_PROFILES=\n' >> .env
	@grep -Eq '^COMPOSE_PROFILES=(.*,)?n8n(,|$$)' .env || \
		sed -i -E 's/^COMPOSE_PROFILES=(.+)$$/COMPOSE_PROFILES=\1,n8n/; s/^COMPOSE_PROFILES=$$/COMPOSE_PROFILES=n8n/' .env
	@grep -Eq '^N8N_ENCRYPTION_KEY=.+' .env || { \
		sed -i '/^N8N_ENCRYPTION_KEY=$$/d' .env; \
		echo "N8N_ENCRYPTION_KEY=$$(openssl rand -hex 32)" >> .env; \
		echo "✓ Generated N8N_ENCRYPTION_KEY in .env (back it up)"; }
	@mkdir -p n8n/data
	@[ "$$(stat -c %u n8n/data)" = 1000 ] || \
		echo "⚠ n8n/data is not owned by UID 1000; run: sudo ./fix-permissions.sh"
	@docker compose up -d n8n
	@echo "n8n enabled: http://localhost:5678"

# Stops and removes the container; n8n/data and the key in .env are kept.
n8n-disable:
	@[ -f .env ] || { echo "❌ .env not found"; exit 1; }
	@docker compose --profile n8n stop n8n
	@docker compose --profile n8n rm -f n8n
	@sed -i -E '/^COMPOSE_PROFILES=/{s/(^|[=,])n8n(,|$$)/\1/; s/,$$//; s/=,/=/}' .env
	@echo "n8n disabled (data kept in n8n/data/)"

# Check Docker and dependencies
check:
	@echo "Checking system requirements..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker not installed"; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo "❌ Docker Compose V2 not installed"; exit 1; }
	@echo "✓ Docker installed: $$(docker --version)"
	@echo "✓ Docker Compose installed: $$(docker compose version)"
	@echo ""
	@echo "Checking network interface..."
	@if [ -f .env ]; then \
		source .env; \
		ip link show $$NETWORK_INTERFACE >/dev/null 2>&1 && \
			echo "✓ Network interface $$NETWORK_INTERFACE exists" || \
			echo "❌ Network interface $$NETWORK_INTERFACE not found"; \
	else \
		echo "⚠ .env file not found. Run 'make setup' first"; \
	fi

# Quick health check
health:
	@echo "Checking service health..."
	@echo ""
	@echo "Grafana:     $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3002 2>/dev/null || echo 'unreachable')"
	@echo "Prometheus:  $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9090 2>/dev/null || echo 'unreachable')"
	@echo "Loki:        $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3100/ready 2>/dev/null || echo 'unreachable')"
	@echo "Portainer:   $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9000 2>/dev/null || echo 'unreachable')"
	@if docker compose ps --services 2>/dev/null | grep -qx n8n; then \
		echo "n8n:         $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:5678/healthz 2>/dev/null || echo 'unreachable')"; fi
	@echo ""
	@echo "(200 = healthy, 302 = redirect/healthy, unreachable = service down)"
