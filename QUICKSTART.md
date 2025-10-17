# Homelab Monitoring Stack - Quick Start Guide

## TL;DR - Get Running in 5 Minutes

```bash
# 1. Navigate to the project directory
cd /media/kshokri/DataVol/Projects/homelab_v2

# 2. Run the setup wizard (automated configuration)
./scripts/setup-wizard.sh

# 3. The wizard will:
#    - Detect your system configuration automatically
#    - Ask for necessary inputs
#    - Generate your .env file
#    - Optionally start all services

# OR manually configure:
cp .env.example .env
nano .env  # Update with your values

# 4. Start the stack
docker compose up -d

# 5. Access your monitoring dashboard
# http://YOUR_SERVER_IP
```

## What You Get

### Observability Stack (Grafana LGTM)
- **Grafana** (http://YOUR_IP:3000) - Unified dashboards for logs and metrics
- **Prometheus** (http://YOUR_IP:9090) - Metrics collection and alerting
- **Loki** (http://YOUR_IP:3100) - Log aggregation
- **Promtail** - Automatic log collection from all containers
- **OpenTelemetry Collector** - Modern telemetry pipeline

### System Monitoring
- **Node Exporter** - CPU, memory, disk, network metrics
- **cAdvisor** - Per-container resource usage
- **ntopng** (http://YOUR_IP:3001) - Network traffic analysis

### Management Tools
- **Portainer** (http://YOUR_IP:9000) - Docker management UI
- **Nginx Proxy Manager** (http://YOUR_IP:81) - Reverse proxy & SSL

### Bonus: Media Streaming
- **Jellyfin** (http://YOUR_IP:8096) - Personal media server

## Setup Options

### Option 1: Automated Setup Wizard (Recommended)

```bash
cd /media/kshokri/DataVol/Projects/homelab_v2
./scripts/setup-wizard.sh
```

The wizard will:
- Auto-detect your IP address and network interface
- Find your user/group IDs
- Detect timezone
- Generate secure passwords
- Find media directories (for Jellyfin)
- Create `.env` file with all settings
- Optionally start services immediately

### Option 2: Manual Configuration

```bash
# Copy template
cp .env.example .env

# Edit configuration
nano .env

# Update these key values:
# - SERVER_IP: Your server's IP (find with: ip a)
# - NETWORK_INTERFACE: Usually eth0, ens18, etc.
# - GRAFANA_ADMIN_PASSWORD: Set a strong password
# - MEDIA_*: Paths to your media (if using Jellyfin)

# Start services
docker compose up -d
```

## Verification Checklist

After starting services, verify everything is working:

```bash
# Check all containers are running
docker compose ps

# Expected: All services should show "Up" status

# Check logs for errors
docker compose logs -f

# Press Ctrl+C to exit logs
```

## First-Time Access

1. **Landing Page**: http://YOUR_IP
   - Shows all services with quick links

2. **Grafana**: http://YOUR_IP:3000
   - Login: admin / (password from .env)
   - Datasources are pre-configured
   - Import recommended dashboards (see README.md)

3. **Prometheus**: http://YOUR_IP:9090
   - Go to Status → Targets
   - All targets should show "UP"

4. **Portainer**: http://YOUR_IP:9000
   - Create admin account on first visit

5. **Nginx Proxy Manager**: http://YOUR_IP:81
   - Login: admin@example.com / changeme
   - **IMPORTANT**: Change password immediately!

## Key Configuration Files

All configurations use the modular pattern - each service is self-contained:

```
service-name/
├── docker-compose.yml    # Service definition
├── config/              # All configs
└── data/               # Runtime data (auto-created, gitignored)
```

### Important Configurations

- **Prometheus scrape targets**: `prometheus/config/prometheus.yml`
- **Prometheus alerts**: `prometheus/config/rules/alerts.yml`
- **Loki retention**: `loki/config/loki-config.yml`
- **Log collection**: `promtail/config/promtail-config.yml`
- **OpenTelemetry pipeline**: `otel-collector/config/otel-collector-config.yml`
- **Network monitoring**: `ntopng/config/ntopng.conf`

## Common Commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# View logs
docker compose logs -f [service-name]

# Restart a service
docker compose restart [service-name]

# Update services
docker compose pull
docker compose up -d

# Check service status
docker compose ps
```

## Default Credentials

**Change these immediately after first login!**

| Service | Username | Password |
|---------|----------|----------|
| Grafana | admin | (from .env) |
| Nginx Proxy Manager | admin@example.com | changeme |
| Portainer | - | Create on first visit |
| Jellyfin | - | Create on first visit |

## Quick Troubleshooting

### Service won't start
```bash
# Check logs
docker compose logs [service-name]

# Common issues:
# - Port already in use: sudo netstat -tlnp | grep [port]
# - Permission issue: Check PUID/PGID in .env
# - Config error: Check relevant config file
```

### Prometheus not scraping
```bash
# Check targets
curl http://localhost:9090/targets

# Verify service is in monitoring network
docker network inspect monitoring
```

### No logs in Loki
```bash
# Check Promtail is running
docker compose ps promtail

# Check Promtail logs
docker compose logs promtail

# Test Loki query in Grafana Explore
```

### ntopng not seeing traffic
```bash
# Verify network interface
ip a

# Update NETWORK_INTERFACE in .env
nano .env

# Restart ntopng
docker compose restart ntopng
```

## What's Next?

1. **Explore Grafana**
   - Import dashboards (Dashboard IDs in README.md)
   - Configure alerting
   - Explore logs in Loki

2. **Secure Your Stack**
   - Change all default passwords
   - Set up firewall rules
   - Configure SSL via Nginx Proxy Manager

3. **Customize**
   - Add custom dashboards
   - Configure alert rules
   - Add monitoring for additional services

4. **Optional: Configure Jellyfin**
   - Add media libraries
   - Set up hardware acceleration
   - Configure remote access

## Need More Help?

- **README.md**: Comprehensive overview and troubleshooting
- **SETUP.md**: Detailed step-by-step setup instructions
- **ARCHITECTURE.md**: Deep dive into design and architecture
- **CLAUDE.md**: Development guide for modifying the stack

## Project Structure

```
homelab_v2/
├── docker-compose.yml           # Main orchestrator (uses include)
├── .env                         # Your configuration
├── .gitignore                   # Git ignore rules
├── README.md                    # Main documentation
├── SETUP.md                     # Detailed setup guide
├── ARCHITECTURE.md              # Architecture details
├── CLAUDE.md                    # Development guide
├── QUICKSTART.md                # This file
│
├── scripts/
│   └── setup-wizard.sh          # Automated setup
│
├── grafana/
│   ├── docker-compose.yml
│   ├── config/
│   └── provisioning/
│
├── loki/
│   ├── docker-compose.yml
│   └── config/
│
├── prometheus/
│   ├── docker-compose.yml
│   └── config/
│
├── otel-collector/
│   ├── docker-compose.yml
│   └── config/
│
├── [other services...]
│
└── [service]/data/              # Created at runtime, gitignored
```

## Support & Resources

- **Grafana**: https://grafana.com/docs/
- **Prometheus**: https://prometheus.io/docs/
- **Loki**: https://grafana.com/docs/loki/
- **OpenTelemetry**: https://opentelemetry.io/docs/
- **Docker Compose**: https://docs.docker.com/compose/

---

**Ready to get started?**

```bash
cd /media/kshokri/DataVol/Projects/homelab_v2
./scripts/setup-wizard.sh
```
