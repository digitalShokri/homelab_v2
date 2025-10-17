# Homelab Monitoring Stack - Detailed Setup Guide

This guide provides step-by-step instructions for deploying the homelab monitoring stack from scratch.

## Prerequisites

### System Requirements

- **Operating System**: Ubuntu Server 22.04+ (or any modern Linux distribution)
- **CPU**: 2+ cores recommended
- **RAM**: Minimum 4GB, 8GB+ recommended
- **Disk Space**: Minimum 20GB free space
- **Network**: Static IP or DHCP reservation recommended

### Required Software

#### Install Docker

```bash
# Update package index
sudo apt update

# Install prerequisites
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
```

#### Verify Installation

```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Test Docker
docker run hello-world
```

## Installation Steps

### Step 1: Clone or Download Repository

```bash
# If using Git
cd /opt  # or your preferred location
git clone <repository-url> homelab-monitoring
cd homelab-monitoring

# Or create directory and download files manually
mkdir -p /opt/homelab-monitoring
cd /opt/homelab-monitoring
# Download/copy files here
```

### Step 2: Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit the environment file
nano .env
```

**Required Configuration:**

```bash
# Your server's IP address (find with: ip a)
SERVER_IP=192.168.1.100

# Network interface for ntopng (find with: ip a)
# Usually: eth0, ens18, enp0s3, etc.
NETWORK_INTERFACE=eth0

# Your user/group IDs (find with: id)
PUID=1000
PGID=1000

# Set strong Grafana admin password
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=YourSecurePassword123!

# Jellyfin published URL
JELLYFIN_PUBLISHED_URL=http://192.168.1.100:8096

# Media paths (adjust to your setup)
MEDIA_MOVIES=/media/movies
MEDIA_TV=/media/tv
MEDIA_MUSIC=/media/music
MEDIA_PHOTOS=/media/photos

# Timezone
TZ=America/New_York
```

### Step 3: Verify Network Interface

```bash
# List network interfaces
ip a

# You should see something like:
# 2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
# Use the name (e.g., eth0) in .env as NETWORK_INTERFACE
```

### Step 4: Create Media Directories (Optional - for Jellyfin)

```bash
# Create media directories if they don't exist
sudo mkdir -p /media/{movies,tv,music,photos}

# Set ownership
sudo chown -R $USER:$USER /media

# Or mount existing media from NAS/external drives
# sudo mount -t nfs NAS_IP:/volume1/media /media
```

### Step 5: Start the Stack

```bash
# Pull all images first (optional but recommended)
docker compose pull

# Start all services in detached mode
docker compose up -d

# Watch the logs as services start
docker compose logs -f
```

**Expected Output:**
```
[+] Running 13/13
 ✔ Network monitoring              Created
 ✔ Container grafana               Started
 ✔ Container prometheus            Started
 ✔ Container loki                  Started
 ✔ Container promtail              Started
 ✔ Container otel-collector        Started
 ✔ Container node-exporter         Started
 ✔ Container cadvisor              Started
 ✔ Container ntopng                Started
 ✔ Container portainer             Started
 ✔ Container nginx-proxy-manager   Started
 ✔ Container jellyfin              Started
 ✔ Container homelab-landing       Started
```

### Step 6: Verify Services

```bash
# Check all containers are running
docker compose ps

# All services should show "Up" status
# If any show "Exited", check logs:
docker compose logs [service-name]
```

### Step 7: Access Services

1. **Landing Page**
   - URL: http://YOUR_SERVER_IP
   - Should show dashboard with all services

2. **Grafana**
   - URL: http://YOUR_SERVER_IP:3000
   - Login: admin / (password from .env)
   - Datasources should be auto-configured

3. **Prometheus**
   - URL: http://YOUR_SERVER_IP:9090
   - Check Status → Targets (all should be "UP")

4. **Portainer**
   - URL: http://YOUR_SERVER_IP:9000
   - Create admin account on first visit

5. **Nginx Proxy Manager**
   - URL: http://YOUR_SERVER_IP:81
   - Login: admin@example.com / changeme
   - **Change password immediately!**

## Post-Installation Configuration

### Configure Grafana Dashboards

1. Login to Grafana
2. Go to Dashboards → Import
3. Import these recommended dashboards:

**Node Exporter Full (ID: 1860)**
```
Dashboard ID: 1860
Prometheus datasource: Prometheus
```

**Docker Container Metrics (ID: 179)**
```
Dashboard ID: 179
Prometheus datasource: Prometheus
```

**Loki Logs (ID: 13639)**
```
Dashboard ID: 13639
Loki datasource: Loki
```

### Configure Prometheus Targets

Verify all targets are being scraped:

1. Open Prometheus: http://YOUR_SERVER_IP:9090
2. Go to Status → Targets
3. All targets should show "UP" status

If any targets are down:
```bash
# Check service is running
docker compose ps [service-name]

# Check service logs
docker compose logs [service-name]

# Restart service if needed
docker compose restart [service-name]
```

### Configure ntopng

1. Access ntopng: http://YOUR_SERVER_IP:3001
2. Configure local networks if needed:
   - Go to Settings → Preferences
   - Set local networks (e.g., 192.168.0.0/16)

### Configure Jellyfin (Optional)

1. Access Jellyfin: http://YOUR_SERVER_IP:8096
2. Complete setup wizard:
   - Create admin account
   - Add media libraries:
     - Movies: /media/movies
     - TV Shows: /media/tv
     - Music: /media/music
     - Photos: /media/photos
3. Configure hardware acceleration if available (Intel QSV, NVIDIA, etc.)

### Configure Nginx Proxy Manager

1. Access NPM: http://YOUR_SERVER_IP:81
2. Login and change default password
3. (Optional) Set up SSL certificates:
   - Add domain name
   - Request Let's Encrypt certificate
   - Create proxy hosts for services

### Configure Alerting

1. In Grafana, go to Alerting → Notification channels
2. Add notification channels (Email, Slack, Discord, etc.)
3. Alert rules are pre-configured in `prometheus/config/rules/alerts.yml`
4. Customize alerts as needed

## Verification Checklist

- [ ] All containers are running (`docker compose ps`)
- [ ] Landing page accessible (http://YOUR_SERVER_IP)
- [ ] Grafana accessible and datasources working
- [ ] Prometheus targets all "UP"
- [ ] Logs appearing in Loki (check Grafana → Explore → Loki)
- [ ] ntopng showing network traffic
- [ ] cAdvisor showing container metrics
- [ ] Portainer accessible
- [ ] Nginx Proxy Manager accessible
- [ ] Jellyfin accessible (if configured)

## Firewall Configuration

### UFW (Ubuntu)

```bash
# Allow SSH (important!)
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow specific service ports (optional - for direct access)
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 9000/tcp  # Portainer

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### iptables

```bash
# Allow established connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Save rules
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

## Maintenance

### Regular Updates

```bash
# Weekly or monthly
cd /opt/homelab-monitoring
docker compose pull
docker compose up -d
docker image prune -f  # Remove old images
```

### Backups

```bash
# Create backup script
cat > /opt/homelab-monitoring/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/homelab-monitoring/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup Grafana
docker run --rm -v $(pwd)/grafana/data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/grafana.tar.gz /data

# Backup Prometheus
docker run --rm -v $(pwd)/prometheus/data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/prometheus.tar.gz /data

# Backup configurations
tar czf $BACKUP_DIR/configs.tar.gz */config/ .env

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x /opt/homelab-monitoring/backup.sh

# Run backup
./backup.sh

# Add to crontab for weekly backups
crontab -e
# Add: 0 2 * * 0 /opt/homelab-monitoring/backup.sh
```

### Monitoring Disk Space

```bash
# Check Docker disk usage
docker system df

# Clean up unused data
docker system prune -a --volumes -f

# Monitor data directories
du -sh */data/
```

## Troubleshooting

See [README.md - Troubleshooting](README.md#troubleshooting) section for common issues and solutions.

## Next Steps

1. Explore Grafana dashboards
2. Set up custom alerts
3. Configure SSL certificates via Nginx Proxy Manager
4. Set up remote access (VPN recommended)
5. Configure additional monitoring targets
6. Customize the landing page

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
