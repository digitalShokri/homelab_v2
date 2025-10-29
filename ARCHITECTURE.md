# Homelab Monitoring Stack - Architecture Documentation

## Design Philosophy

This monitoring stack follows a modular, self-contained design pattern where each service lives in its own directory with all necessary configurations. This approach provides:

- **Modularity**: Services can be added, removed, or replaced independently
- **Maintainability**: Clear separation of concerns, easy to understand and modify
- **Version Control**: Only configuration tracked in Git, data directories ignored
- **Portability**: Easy to move or duplicate services

## Modular Service Pattern

Based on the `landing-page/` reference implementation, each service follows this structure:

```
service-name/
├── docker-compose.yml    # Service-specific compose configuration
├── config/              # Configuration files
│   ├── service.conf
│   └── rules/           # Optional: alert rules, etc.
├── data/               # Runtime data (gitignored)
└── README.md           # Optional: service-specific docs
```

The main `docker-compose.yml` orchestrates all services using the `include:` directive:

```yaml
include:
  - path: ./grafana/docker-compose.yml
  - path: ./prometheus/docker-compose.yml
  # ... other services
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Landing Page (Nginx)                     │
│                      http://server-ip:80                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Grafana    │    │  Portainer   │    │   Jellyfin   │
│   :3000      │    │   :9000      │    │   :8096      │
└──────┬───────┘    └──────────────┘    └──────────────┘
       │
       │ Queries
       │
┌──────┴───────────────────────────────────────────────┐
│                                                       │
│  ┌─────────────┐    ┌─────────────┐    ┌──────────┐ │
│  │ Prometheus  │    │    Loki     │    │  Tempo   │ │
│  │   :9090     │    │   :3100     │    │ (future) │ │
│  └──────┬──────┘    └──────┬──────┘    └──────────┘ │
│         │                   │                        │
│         │ Scrapes           │ Receives               │
│         │                   │                        │
└─────────┼───────────────────┼────────────────────────┘
          │                   │
          │                   │
    ┌─────┴────────┬──────────┴──────┬────────────┐
    │              │                 │            │
    ▼              ▼                 ▼            ▼
┌─────────┐  ┌─────────────┐  ┌──────────┐  ┌─────────┐
│  Node   │  │    OTEL     │  │ Promtail │  │cAdvisor │
│Exporter │  │  Collector  │  │  :9080   │  │  :8080  │
│  :9100  │  │4317/4318/... │  └────┬─────┘  └─────────┘
└─────────┘  └──────┬──────┘       │
                    │              │ Reads logs
        ┌───────────┼──────────────┼───────────┐
        │           │              │           │
        ▼           ▼              ▼           ▼
    ┌────────────────────────────────────────────┐
    │         Docker Engine & Containers         │
    │              /var/log/*                    │
    │       /var/lib/docker/containers/*         │
    └────────────────────────────────────────────┘
                    │
                    │ Network Traffic
                    ▼
            ┌──────────────┐
            │    ntopng    │
            │    :3001     │
            │  (host mode) │
            └──────────────┘
```

## Data Flow

### Logs Pipeline

```
Docker Containers
       │
       ├─> Container logs (/var/lib/docker/containers/*.log)
       │          │
       │          ▼
       │    ┌──────────┐
       │    │ Promtail │
       │    └────┬─────┘
       │         │
       │         │ HTTP Push
       │         ▼
       │    ┌─────────┐
       │    │  Loki   │
       │    └────┬────┘
       │         │
       │         │ LogQL Queries
       │         ▼
       │    ┌─────────┐
       └────>│ Grafana │
            └─────────┘

System Logs (/var/log/*)
       │
       └─> Promtail ─> Loki ─> Grafana
```

### Metrics Pipeline

```
Host System
       │
       ▼
┌─────────────┐
│    Node     │
│  Exporter   │
└──────┬──────┘
       │
       │ Prometheus Scrape
       ▼
┌─────────────┐         ┌──────────┐
│  Prometheus │ <────── │ Grafana  │
└──────┬──────┘  Query  └──────────┘
       ▲
       │ Scrape
       │
       ├─ cAdvisor (container metrics)
       ├─ OTEL Collector (unified metrics)
       ├─ ntopng (network metrics)
       └─ Service endpoints (Grafana, Loki self-metrics)
```

### OpenTelemetry Pipeline

```
Applications
       │
       │ OTLP (gRPC/HTTP)
       ▼
┌──────────────────┐
│ OTEL Collector   │
│                  │
│ Receivers:       │
│  - OTLP          │
│  - Host Metrics  │
│  - Docker Stats  │
│  - Prometheus    │
│                  │
│ Processors:      │
│  - Batch         │
│  - Resource      │
│  - Attributes    │
│                  │
│ Exporters:       │
│  - Prometheus    │
│  - Loki          │
│  - (Tempo)       │
└────┬─────┬───────┘
     │     │
     │     └─> Loki (logs)
     │
     └─> Prometheus (metrics)
```

## Network Architecture

### Docker Networks

- **monitoring** (bridge): Main network for all services
  - Subnet: 172.20.0.0/16
  - All services except ntopng connect here
  - Enables service-to-service communication by name

- **host** (ntopng only): Required for packet capture
  - ntopng needs raw access to network interface
  - Cannot use bridge network for deep packet inspection

### Service Communication Matrix

| From Service | To Service | Protocol | Port | Purpose |
|--------------|------------|----------|------|---------|
| Grafana | Prometheus | HTTP | 9090 | Query metrics |
| Grafana | Loki | HTTP | 3100 | Query logs |
| Prometheus | Node Exporter | HTTP | 9100 | Scrape metrics |
| Prometheus | cAdvisor | HTTP | 8080 | Scrape metrics |
| Prometheus | OTEL Collector | HTTP | 8889 | Scrape metrics |
| Promtail | Loki | HTTP | 3100 | Push logs |
| OTEL Collector | Prometheus | HTTP | 9090 | Remote write |
| OTEL Collector | Loki | HTTP | 3100 | Push logs |
| Applications | OTEL Collector | gRPC | 4317 | Send telemetry |
| Applications | OTEL Collector | HTTP | 4318 | Send telemetry |
| Landing Page | All Services | HTTP | Various | Reverse proxy |

## Storage Strategy

### Persistent Data

| Service | Storage Type | Location | Purpose | Retention |
|---------|-------------|----------|---------|-----------|
| Prometheus | TSDB | `prometheus/data/` | Metrics time-series | 15 days |
| Loki | BoltDB + Chunks | `loki/data/` | Log index + chunks | 30 days |
| Grafana | SQLite | `grafana/data/` | Dashboards, users | Persistent |
| ntopng | RRD + SQLite | `ntopng/data/`, `ntopng/lib/` | Flow data, RRDs | 7 days |
| Portainer | JSON | `portainer/data/` | Config | Persistent |
| Jellyfin | SQLite + Files | `jellyfin/config/` | Media metadata | Persistent |
| NPM | SQLite | `nginx-proxy-manager/data/` | Proxy configs | Persistent |

### Data Retention

**Prometheus**:
- Configured via `--storage.tsdb.retention.time=15d`
- Adjustable in `prometheus/docker-compose.yml`
- Longer retention = more disk space

**Loki**:
- Configured in `loki/config/loki-config.yml`
- `retention_period: 720h` (30 days)
- Compactor runs every 10 minutes to delete old data

**ntopng**:
- RRD files: Automatically rotated
- Flow data: 7 days in SQLite
- Configured in `ntopng/config/ntopng.conf`

### Backup Strategy

**Critical Data** (should be backed up):
- Grafana dashboards and datasources: `grafana/data/`
- Prometheus data (optional): `prometheus/data/`
- Jellyfin metadata: `jellyfin/config/`
- NPM configurations: `nginx-proxy-manager/data/`
- All `*/config/` directories

**Non-Critical Data** (can be regenerated):
- Loki logs: `loki/data/`
- ntopng flow data: `ntopng/data/`
- cAdvisor data: (in-memory)
- Promtail positions: (regenerated)

## Security Architecture

### Authentication & Authorization

| Service | Auth Method | Default Credentials | Notes |
|---------|-------------|-------------------|-------|
| Grafana | Username/Password | admin / (from .env) | LDAP/OAuth supported |
| Portainer | Username/Password | Create on first visit | MFA available |
| NPM | Username/Password | admin@example.com / changeme | **Change immediately!** |
| Jellyfin | Username/Password | Create on first visit | Optional |
| Prometheus | None | - | Add auth via NPM |
| Loki | None | - | Internal only |
| ntopng | Optional | Disabled by default | Can enable in config |

### Network Security

**Internal-Only Services** (not exposed to internet):
- Loki (port 3100)
- OTEL Collector (ports 4317, 4318, 8888, 8889)
- Promtail (port 9080)
- Node Exporter (port 9100)

**Exposed Services** (accessible from LAN):
- Landing Page (port 80)
- Grafana (port 3000)
- Prometheus (port 9090)
- Portainer (port 9000)
- Jellyfin (port 8096)
- ntopng (port 3001)
- cAdvisor (port 8080)
- NPM (port 81)

**SSL/TLS**:
- Use Nginx Proxy Manager for SSL termination
- Let's Encrypt integration for free certificates
- Recommended for internet-exposed services

### Firewall Recommendations

```bash
# Minimal exposure
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP (NPM)
sudo ufw allow 443   # HTTPS (NPM)
sudo ufw enable

# All other services accessed via NPM reverse proxy
```

## Scalability Considerations

### Current Limitations

- **Single Node**: All services on one host
- **No High Availability**: Single point of failure
- **Storage**: Local disk only
- **No Clustering**: Services are standalone

### Scaling Path

**Horizontal Scaling** (future):
1. Prometheus federation for multiple scrapers
2. Loki distributed mode with object storage
3. Load balancer in front of Grafana
4. Separate OTEL Collector instances per region

**Vertical Scaling** (current):
- Increase container resource limits
- Add more CPU/RAM to host
- Use faster storage (SSD/NVMe)

## Monitoring the Monitors

### Self-Monitoring

- Prometheus scrapes its own metrics
- Grafana dashboard for Prometheus health
- Loki logs its own operations
- OTEL Collector exposes metrics on :8888

### Health Checks

- Docker health checks configured per service
- OTEL Collector health check endpoint: `:13133`
- Prometheus targets page shows scrape status
- Grafana Alerting monitors critical services

## Extensibility

### Adding New Services

1. Create service directory: `mkdir -p new-service/config`
2. Create `new-service/docker-compose.yml`
3. Add configuration files to `new-service/config/`
4. Add include to main `docker-compose.yml`
5. If exposing metrics: Add scrape job to Prometheus
6. If generating logs: Promtail auto-discovers Docker logs
7. Update landing page if user-facing

### Adding Custom Metrics

**Via OpenTelemetry**:
1. Instrument application with OTEL SDK
2. Export to OTEL Collector (`:4317` or `:4318`)
3. Metrics automatically forwarded to Prometheus

**Via Prometheus**:
1. Expose `/metrics` endpoint in application
2. Add scrape job to `prometheus/config/prometheus.yml`
3. Restart Prometheus

### Adding Custom Alerts

1. Edit `prometheus/config/rules/alerts.yml`
2. Add new alert rule
3. Reload Prometheus: `docker compose restart prometheus`
4. Configure notification in Grafana Alerting

## Technology Choices

### Why OpenTelemetry?

- **Vendor Neutral**: Not locked into specific vendors
- **Unified Pipeline**: Single agent for logs, metrics, traces
- **Future Proof**: Industry standard, growing adoption
- **Flexible**: Supports many receivers and exporters

### Why Loki Over ELK?

- **Lightweight**: Lower resource usage
- **LogQL**: Familiar syntax (similar to PromQL)
- **Native Grafana Integration**: Seamless correlation
- **Simpler**: No separate Elasticsearch cluster needed

### Why ntopng for Network Monitoring?

- **Deep Packet Inspection**: Layer 7 visibility
- **Established**: Mature, stable project
- **Self-Contained**: Built-in storage (RRD)
- **Rich UI**: Comprehensive network analytics

### Why Local Storage?

- **Simplicity**: No external dependencies
- **Performance**: Fast local disk access
- **Cost**: No cloud storage fees
- **Privacy**: All data stays local

## Future Enhancements

### Planned

- [ ] Tempo integration for distributed tracing
- [ ] Alertmanager for advanced alerting
- [ ] Mimir for long-term metrics storage
- [ ] Service mesh observability (if needed)

### Possible

- [ ] External authentication (LDAP/OAuth)
- [ ] Object storage backend (S3/MinIO)
- [ ] Multi-tenant support
- [ ] Distributed deployment
- [ ] Kubernetes migration

## References

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Loki Architecture](https://grafana.com/docs/loki/latest/fundamentals/architecture/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Docker Compose Spec](https://docs.docker.com/compose/compose-file/)
