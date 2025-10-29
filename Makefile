.PHONY: help setup start stop restart status logs pull update clean backup

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
	@echo "Quick Access URLs:"
	@echo "  Landing Page: http://localhost or http://YOUR_SERVER_IP"
	@echo "  Grafana:      http://localhost:3000"
	@echo "  Prometheus:   http://localhost:9090"
	@echo "  Portainer:    http://localhost:9000"

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
backup:
	@echo "Creating backup..."
	@mkdir -p backups
	@tar czf backups/homelab-backup-$$(date +%Y%m%d-%H%M%S).tar.gz \
		*/config/ \
		.env \
		docker-compose.yml \
		*/docker-compose.yml \
		--exclude='*/data' \
		--exclude='*/cache' \
		--exclude='*/lib'
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
	@echo "Grafana:     $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3000 2>/dev/null || echo 'unreachable')"
	@echo "Prometheus:  $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9090 2>/dev/null || echo 'unreachable')"
	@echo "Loki:        $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3100/ready 2>/dev/null || echo 'unreachable')"
	@echo "Portainer:   $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9000 2>/dev/null || echo 'unreachable')"
	@echo ""
	@echo "(200 = healthy, 302 = redirect/healthy, unreachable = service down)"
