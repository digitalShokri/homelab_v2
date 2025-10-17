# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a modern, modular homelab monitoring stack built with OpenTelemetry and the Grafana observability stack. It provides comprehensive monitoring of Docker containers, host systems, network traffic, and applications using industry-standard telemetry tools.

## Architecture Pattern: Modular Service Design

**Key Principle**: Each service is self-contained in its own directory with all configurations.

```
service-name/
├── docker-compose.yml    # Service-specific compose file
├── config/              # All configuration files
└── data/               # Runtime data (gitignored)
```

Main `docker-compose.yml` uses `include:` directive to compose all services:

```yaml
include:
  - path: ./grafana/docker-compose.yml
  - path: ./prometheus/docker-compose.yml
  # ...
```

## Stack Components

### Core Observability (Grafana LGTM Stack)
- **Grafana** (port 3000): Visualization, dashboards, alerting
- **Loki** (port 3100): Log aggregation using LogQL
- **Prometheus** (port 9090): Metrics storage using PromQL
- **Promtail** (port 9080): Log collection from Docker and system

### Telemetry Collection
- **OpenTelemetry Collector** (ports 4317/4318): Unified telemetry pipeline
  - Receives: OTLP (gRPC/HTTP), host metrics, Docker stats
  - Exports: Prometheus (metrics), Loki (logs)
- **Node Exporter** (port 9100): Host system metrics
- **cAdvisor** (port 8080): Container resource metrics
- **ntopng** (port 3001): Network traffic analysis (host network mode)

### Management Services
- **Portainer** (port 9000): Docker management UI
- **Nginx Proxy Manager** (port 81): Reverse proxy, SSL termination

### Applications
- **Jellyfin** (port 8096): Media streaming server
- **Landing Page** (port 80): Custom service dashboard

## Key Configuration Files

### Environment Variables (`.env`)
All environment-specific configuration. Key variables:
- `SERVER_IP`: Server IP address
- `NETWORK_INTERFACE`: Interface for ntopng (e.g., eth0)
- `GRAFANA_ADMIN_PASSWORD`: Grafana admin password
- `MEDIA_*`: Media paths for Jellyfin
- `PUID`/`PGID`: User/group IDs

### Prometheus (`prometheus/config/prometheus.yml`)
- **Scrape configs**: Defines what to monitor
- **Scrape interval**: 15s default
- **Retention**: Controlled by env var `PROMETHEUS_RETENTION` (default: 15d)
- **Alert rules**: Located in `prometheus/config/rules/alerts.yml`

### Loki (`loki/config/loki-config.yml`)
- **Retention**: 720h (30 days) via `retention_period`
- **Storage**: BoltDB (index) + Filesystem (chunks)
- **Compactor**: Runs every 10m to delete old logs

### Promtail (`promtail/config/promtail-config.yml`)
- **Docker logs**: Auto-discovers via Docker socket
- **System logs**: Scrapes `/var/log/*`
- **Labels**: Extracts container name, service, project from Docker labels

### OpenTelemetry Collector (`otel-collector/config/otel-collector-config.yml`)
- **Receivers**: OTLP, hostmetrics, prometheus, docker_stats
- **Processors**: batch, resourcedetection, attributes
- **Exporters**: prometheus (metrics), loki (logs)
- **Telemetry endpoint**: `:8888` (collector's own metrics)

### ntopng (`ntopng/config/ntopng.conf`)
- **Interface**: Configured via `NETWORK_INTERFACE` env var
- **Storage**: RRD files + SQLite (local, no external DB)
- **Runs in host network mode**: Required for packet capture
- **Data dir**: `ntopng/data/` and `ntopng/lib/`

### Grafana Provisioning
- **Datasources**: `grafana/provisioning/datasources/`
  - `prometheus.yml`: Auto-configures Prometheus datasource
  - `loki.yml`: Auto-configures Loki datasource
- **Dashboards**: `grafana/provisioning/dashboards/` (JSON files)

## Common Development Tasks

### Start/Stop Services

```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d [service-name]

# Stop all services
docker compose down

# Restart service after config change
docker compose restart [service-name]
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f [service-name]

# Tail last 100 lines
docker compose logs --tail=100 [service-name]
```

### Configuration Changes

**For services with hot-reload** (Prometheus, Grafana):
```bash
# Edit config file
nano [service]/config/[config-file]

# Reload without restart (Prometheus only)
curl -X POST http://localhost:9090/-/reload

# Or restart service
docker compose restart [service-name]
```

**For services without hot-reload**:
```bash
# Edit config
nano [service]/config/[config-file]

# Restart service
docker compose restart [service-name]
```

### Adding a New Service

1. Create directory structure:
   ```bash
   mkdir -p new-service/config
   ```

2. Create `new-service/docker-compose.yml`:
   ```yaml
   services:
     new-service:
       image: image-name:tag
       container_name: new-service
       restart: unless-stopped
       ports:
         - "PORT:PORT"
       volumes:
         - ./config:/config
         - ./data:/data
       networks:
         - monitoring
   ```

3. Add to main `docker-compose.yml`:
   ```yaml
   include:
     - path: ./new-service/docker-compose.yml
   ```

4. If the service exposes metrics, add Prometheus scrape job:
   ```yaml
   # prometheus/config/prometheus.yml
   scrape_configs:
     - job_name: 'new-service'
       static_configs:
         - targets: ['new-service:PORT']
   ```

5. Logs are auto-collected by Promtail (Docker logs)

6. Update landing page if user-facing service

### Adding Prometheus Alerts

1. Edit `prometheus/config/rules/alerts.yml`
2. Add alert rule:
   ```yaml
   groups:
     - name: my_alerts
       interval: 30s
       rules:
         - alert: MyAlert
           expr: metric_name > threshold
           for: 5m
           labels:
             severity: warning
           annotations:
             summary: "Alert description"
             description: "{{ $labels.instance }} details"
   ```

3. Reload Prometheus:
   ```bash
   docker compose restart prometheus
   ```

4. Configure notifications in Grafana → Alerting

### Modifying Loki Log Retention

1. Edit `loki/config/loki-config.yml`:
   ```yaml
   limits_config:
     retention_period: 720h  # Change this (hours)
   ```

2. Restart Loki:
   ```bash
   docker compose restart loki
   ```

### Modifying Prometheus Retention

1. Update `.env`:
   ```bash
   PROMETHEUS_RETENTION=30d  # Change retention
   ```

2. Restart Prometheus:
   ```bash
   docker compose restart prometheus
   ```

### Updating ntopng Network Interface

1. Check available interfaces:
   ```bash
   ip a
   ```

2. Update `.env`:
   ```bash
   NETWORK_INTERFACE=ens18  # Your interface
   ```

3. Restart ntopng:
   ```bash
   docker compose restart ntopng
   ```

## Data Flow Understanding

### How Logs Flow
```
Container logs → Promtail (scrapes /var/lib/docker/containers/) →
Loki (stores) → Grafana (queries via LogQL)
```

### How Metrics Flow
```
Exporter (node-exporter, cadvisor) →
Prometheus (scrapes every 15s) →
Grafana (queries via PromQL)

OR

Application → OTEL Collector (receivers) →
OTEL Collector (exporters) → Prometheus → Grafana
```

### How Network Monitoring Works
```
Network packets → ntopng (captures via eth0 in host mode) →
RRD/SQLite (stores) → ntopng Web UI (displays)
```

## Important File Locations

### Configuration Files (tracked in Git)
- `*/config/*.yml` - Service configurations
- `*/config/*.conf` - Additional configs
- `grafana/provisioning/` - Auto-provisioned datasources/dashboards
- `.env.example` - Environment variable template
- `*/docker-compose.yml` - Service definitions

### Data Directories (gitignored)
- `*/data/` - Runtime data
- `*/cache/` - Cache data
- `*/lib/` - Libraries/additional data
- `jellyfin/config/` - Jellyfin metadata
- `nginx-proxy-manager/data/` - NPM configs
- `nginx-proxy-manager/letsencrypt/` - SSL certificates

## Networking

### Docker Network
- **Name**: `monitoring`
- **Type**: bridge
- **Subnet**: 172.20.0.0/16
- **Usage**: All services except ntopng

### Service Communication
Services communicate by container name (Docker DNS):
- `http://grafana:3000`
- `http://prometheus:9090`
- `http://loki:3100`
- etc.

### ntopng Special Case
- Uses `network_mode: host` for packet capture
- Accesses services via `localhost:PORT` or `172.20.0.x:PORT`
- Requires `NET_ADMIN` and `NET_RAW` capabilities

## Port Reference

| Service | Port | Protocol | Exposed |
|---------|------|----------|---------|
| Landing Page | 80 | HTTP | Yes |
| Grafana | 3000 | HTTP | Yes |
| Prometheus | 9090 | HTTP | Yes |
| Loki | 3100 | HTTP | Internal |
| OTEL Collector | 4317 | gRPC | Internal |
| OTEL Collector | 4318 | HTTP | Internal |
| OTEL Collector | 8888 | HTTP | Internal |
| OTEL Collector | 8889 | HTTP | Internal |
| Promtail | 9080 | HTTP | Internal |
| ntopng | 3001 | HTTP | Yes |
| Node Exporter | 9100 | HTTP | Internal |
| cAdvisor | 8080 | HTTP | Yes |
| Portainer | 9000 | HTTP | Yes |
| NPM | 81 | HTTP | Yes |
| NPM | 443 | HTTPS | Yes |
| Jellyfin | 8096 | HTTP | Yes |

## Troubleshooting Common Issues

### Service Won't Start
```bash
# Check logs
docker compose logs [service-name]

# Check if port is in use
sudo netstat -tlnp | grep [port]

# Check service health
docker compose ps [service-name]
```

### Prometheus Not Scraping
1. Check targets: `http://localhost:9090/targets`
2. Verify service is in `monitoring` network
3. Test connectivity:
   ```bash
   docker exec prometheus ping [target-service]
   ```

### Loki Not Receiving Logs
1. Check Promtail is running: `docker compose ps promtail`
2. Check Promtail logs: `docker compose logs promtail`
3. Verify Loki datasource in Grafana
4. Test query in Grafana Explore: `{container="prometheus"}`

### ntopng Not Capturing Traffic
1. Verify interface: `ip a`
2. Update `NETWORK_INTERFACE` in `.env`
3. Check ntopng has proper capabilities:
   ```bash
   docker inspect ntopng | grep -A 10 CapAdd
   ```
4. Restart: `docker compose restart ntopng`

### OTEL Collector Not Working
1. Check OTEL Collector logs: `docker compose logs otel-collector`
2. Check health endpoint: `curl http://localhost:13133`
3. Verify receivers are accepting data
4. Check exporters are sending to Prometheus/Loki

## Security Notes

### Default Credentials
- Grafana: `admin` / (from `.env`)
- NPM: `admin@example.com` / `changeme` (CHANGE IMMEDIATELY!)
- Portainer: Create on first visit
- Jellyfin: Create on first visit

### No Authentication (Internal Only)
- Prometheus
- Loki
- OTEL Collector
- Promtail
- Node Exporter
- cAdvisor

### Securing Services
Use Nginx Proxy Manager to:
1. Add SSL certificates (Let's Encrypt)
2. Add authentication layers
3. Create reverse proxy rules
4. Restrict access by IP

## Performance Tuning

### Prometheus
- Adjust scrape interval in `prometheus.yml` (trade-off: granularity vs load)
- Reduce retention if disk space limited
- Use recording rules for expensive queries

### Loki
- Adjust `ingestion_rate_mb` and `per_stream_rate_limit` for high-volume logs
- Reduce retention if disk space limited
- Use LogQL filters to reduce query load

### OTEL Collector
- Adjust batch processor `timeout` and `send_batch_size`
- Configure `memory_limiter` to prevent OOM
- Enable/disable specific receivers based on needs

## Best Practices for Modifications

1. **Always edit configs in `*/config/` directories**
2. **Test changes on non-production first**
3. **Back up before major changes**:
   ```bash
   tar czf backup-$(date +%Y%m%d).tar.gz */config/ .env
   ```
4. **Use environment variables** in `.env` instead of hardcoding
5. **Document custom dashboards** in Grafana or export to `grafana/provisioning/dashboards/`
6. **Version control all config changes** in Git
7. **Never commit data directories** (already gitignored)

## Useful Query Examples

### PromQL (Prometheus)
```promql
# CPU usage by container
rate(container_cpu_usage_seconds_total[5m]) * 100

# Memory usage by container
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# Disk usage by mount
100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)
```

### LogQL (Loki)
```logql
# All logs from Prometheus container
{container="prometheus"}

# Error logs across all containers
{container=~".+"} |= "error"

# Logs from specific service with level filter
{com_docker_compose_service="grafana"} | json | level="error"
```

## Documentation References

- [README.md](README.md) - Getting started and quick reference
- [SETUP.md](SETUP.md) - Detailed setup instructions
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture details and design decisions
- [Grafana Docs](https://grafana.com/docs/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Loki Docs](https://grafana.com/docs/loki/)
- [OpenTelemetry Docs](https://opentelemetry.io/docs/)

## Development Workflow

When making changes:

1. **Read** relevant config file
2. **Edit** using Edit tool (preserving exact formatting)
3. **Test** by restarting affected service
4. **Verify** service still works (check logs, access UI)
5. **Document** significant changes in comments or docs

When adding features:

1. **Plan** the architecture change
2. **Create** new service directory if needed
3. **Configure** service-specific settings
4. **Integrate** with main compose file
5. **Add monitoring** (Prometheus scrape, Loki collection)
6. **Test** thoroughly
7. **Document** in relevant .md files
