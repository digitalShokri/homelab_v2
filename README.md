# Homelab Monitoring Stack v2.0

A modern, modular monitoring stack built with OpenTelemetry and the Grafana LGTM stack (Loki, Grafana, Tempo, Mimir/Prometheus) for comprehensive homelab observability.

## 🌟 Features

- **Unified Observability**: Single pane of glass in Grafana for logs, metrics, and traces
- **OpenTelemetry Standard**: Future-proof, vendor-neutral telemetry collection
- **Modular Design**: Each service is self-contained with its own configuration
- **Network Monitoring**: ntopng for deep packet inspection and network analysis
- **Container Metrics**: Full Docker container and host resource monitoring
- **Log Aggregation**: Centralized logging with Loki and Promtail
- **Media Streaming**: Integrated Jellyfin media server
- **Easy Management**: Portainer for container management, Nginx Proxy Manager for reverse proxy

## 📋 Stack Components

### Core Observability
- **Grafana** - Unified visualization and dashboards
- **Loki** - Log aggregation and querying
- **Prometheus** - Metrics storage and alerting
- **Promtail** - Log collection from containers and system
- **OpenTelemetry Collector** - Unified telemetry pipeline

### Monitoring & Metrics
- **Node Exporter** - Host system metrics
- **cAdvisor** - Container resource metrics
- **ntopng** - Network traffic analysis
- **NVIDIA GPU Exporter** - GPU metrics (temperature, memory, utilization)

### Management
- **Portainer** - Docker container management UI
- **Nginx Proxy Manager** - Reverse proxy and SSL management

### Applications
- **Jellyfin** - Personal media streaming server
- **Landing Page** - Custom dashboard for all services

## 🚀 Quick Start

### Prerequisites

- Ubuntu Server (or any Linux distribution)
- Docker and Docker Compose V2 installed
- At least 4GB RAM and 20GB free disk space
- Root or sudo access

### Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url> homelab_v2
   cd homelab-monitoring
   ```

2. **Copy environment template**
   ```bash
   cp .env.example .env
   ```

3. **Edit `.env` file with your configuration**
   ```bash
   nano .env
   ```

   Update the following:
   - `SERVER_IP`: Your server's IP address
   - `NETWORK_INTERFACE`: Your network interface (find with `ip a`)
   - `GRAFANA_ADMIN_PASSWORD`: Set a secure password
   - `MEDIA_*`: Paths to your media directories (for Jellyfin)

4. **Start the stack**
   ```bash
   docker compose up -d
   ```

5. **Verify all services are running**
   ```bash
   docker compose ps
   ```

6. **Access the landing page**
   ```
   http://192.168.1.241
   ```

## 🔗 Service Access

Once deployed, access services at:

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| **Landing Page** | http://192.168.1.241 | - |
| **Grafana** | http://192.168.1.241:3002 | admin / (see .env) |
| **Prometheus** | http://192.168.1.241:9090 | - |
| **Loki** | http://192.168.1.241:3100 | - |
| **Portainer** | http://192.168.1.241:9000 | Create on first visit |
| **Nginx Proxy Mgr** | http://192.168.1.241:81 | admin@example.com / changeme |
| **Jellyfin** | http://192.168.1.241:8096 | Create on first visit |
| **ntopng** | http://192.168.1.241:3000 | No login required |
| **cAdvisor** | http://192.168.1.241:8080 | - |
| **NVIDIA GPU Exporter** | http://192.168.1.241:9445/metrics | - |

## 📊 Post-Deployment Configuration

### Grafana Setup

1. Login to Grafana (credentials from `.env`)
2. Datasources are auto-configured via provisioning
3. Import recommended dashboards:
   - Node Exporter Full: ID `1860`
   - Docker Container Metrics: ID `179`
   - Loki Logs Dashboard: ID `13639`
   - cAdvisor: ID `14282`
   - NVIDIA GPU Metrics: ID `14574` (for GPU monitoring)

### Alerting Setup

1. Navigate to Grafana → Alerting
2. Configure notification channels (email, Slack, etc.)
3. Alert rules are pre-configured in `prometheus/config/rules/alerts.yml`

## 🛠️ Management Commands

### Start/Stop/Restart

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart specific service
docker compose restart [service-name]

# Example: Restart Grafana
docker compose restart grafana
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f [service-name]

# Example: View Prometheus logs
docker compose logs -f prometheus
```

### Update Services

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d
```

### Backup Data

```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d)

# Backup Grafana data
docker run --rm -v $(pwd)/grafana/data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/grafana-$(date +%Y%m%d).tar.gz /data

# Backup Prometheus data
docker run --rm -v $(pwd)/prometheus/data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/prometheus-$(date +%Y%m%d).tar.gz /data
```

## 📁 Directory Structure

```
homelab-monitoring/
├── docker-compose.yml          # Main orchestrator
├── .env                        # Environment variables
├── .gitignore                  # Git ignore rules
│
├── grafana/                    # Grafana service
│   ├── docker-compose.yml
│   ├── config/
│   └── provisioning/
│
├── loki/                       # Loki service
│   ├── docker-compose.yml
│   └── config/
│
├── prometheus/                 # Prometheus service
│   ├── docker-compose.yml
│   └── config/
│
├── otel-collector/             # OpenTelemetry service
│   ├── docker-compose.yml
│   └── config/
│
└── [other services...]
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

## 🔒 Security Recommendations

1. **Change Default Passwords**
   - Grafana admin password (in `.env`)
   - Nginx Proxy Manager (admin@example.com)
   - Create secure Portainer admin account

2. **Configure Firewall**
   ```bash
   sudo ufw allow 22        # SSH
   sudo ufw allow 80        # HTTP
   sudo ufw allow 443       # HTTPS
   sudo ufw enable
   ```

3. **Use Nginx Proxy Manager**
   - Set up SSL certificates with Let's Encrypt
   - Add authentication to services
   - Configure reverse proxy rules

4. **Regular Updates**
   ```bash
   # Update Docker images weekly
   docker compose pull && docker compose up -d
   ```

## 🐛 Troubleshooting

### Service Won't Start

```bash
# Check logs
docker compose logs [service-name]

# Check if port is already in use
sudo netstat -tlnp | grep [port]

# Restart service
docker compose restart [service-name]
```

### ntopng Not Capturing Traffic

1. Verify network interface:
   ```bash
   ip a
   ```

2. Update `NETWORK_INTERFACE` in `.env`

3. Ensure ntopng has proper capabilities:
   ```bash
   docker compose down
   docker compose up -d ntopng
   ```

### Prometheus Not Scraping Targets

1. Check target status: http://192.168.1.241:9090/targets
2. Verify services are in the `monitoring` network
3. Check service names resolve:
   ```bash
   docker exec prometheus ping grafana
   ```

### Loki Not Receiving Logs

1. Check Promtail is running:
   ```bash
   docker compose ps promtail
   ```

2. Check Promtail logs:
   ```bash
   docker compose logs promtail
   ```

3. Verify Loki endpoint in Grafana datasources

## 📚 Additional Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed architecture and design patterns
- [SETUP.md](SETUP.md) - Step-by-step setup guide
- [CLAUDE.md](CLAUDE.md) - Development guide for Claude Code

## 🤝 Contributing

This is a personal homelab project. Feel free to fork and adapt to your needs.

## 📝 License

MIT License - feel free to use and modify as needed.

## 🙏 Acknowledgments

Built with:
- [Grafana](https://grafana.com/)
- [Prometheus](https://prometheus.io/)
- [Loki](https://grafana.com/oss/loki/)
- [OpenTelemetry](https://opentelemetry.io/)
- [ntopng](https://www.ntop.org/)
- [Jellyfin](https://jellyfin.org/)
- [Portainer](https://www.portainer.io/)
