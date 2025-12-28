# 🛡️ Mini-SOC - Complete Security Operations Center Lab

A complete, containerized Security Operations Center (SOC) environment for learning, testing, and demonstrating security automation workflows.

## 📋 Table of Contents

- [Architecture](#architecture)
- [Components](#components)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Initial Setup](#initial-setup)
- [Access URLs](#access-urls)
- [Default Credentials](#default-credentials)
- [Usage Guide](#usage-guide)
- [Integration Workflows](#integration-workflows)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│              Data Ingestion & Analysis               │
│  Logstash:5044 ──► Elasticsearch:9200 ──► Kibana:5601│
└─────────────────────────────────────────────────────┘
                              │
                              ├──► Cortex:9001 (Analyzers)
                              │
                              ▼
┌─────────────────────────────────────────────────────┐
│            Incident Response & Orchestration         │
│  Shuffle:3001 ◄──► TheHive:9000 ◄──► Cortex:9001   │
│       │                 │                             │
│       │                 ├──► Cassandra:9042          │
│       │                 ├──► MinIO:9002              │
│       │                 └──► Redis:6379              │
└─────────────────────────────────────────────────────┘
```

---

## 🧩 Components

| Component | Version | Purpose | Port(s) |
|-----------|---------|---------|---------|
| **Elasticsearch** | 8.11.0 | Log storage & search engine | 9200, 9300 |
| **Kibana** | 8.11.0 | Data visualization & alerting | 5601 |
| **Logstash** | 8.11.0 | Log ingestion & processing | 5044, 9600 |
| **TheHive** | 5.2 | Incident response platform | 9000 |
| **Cortex** | 3.1.7 | Observable analysis engine | 9001 |
| **Shuffle** | Latest | SOAR automation platform | 3001, 3443 |
| **Cassandra** | 4.1 | Database for TheHive | 9042 |
| **Redis** | 7 | Cache for TheHive/Cortex | 6379 |
| **MinIO** | Latest | Object storage for files | 9002, 9003 |

---

## 📦 Prerequisites

### System Requirements

- **RAM**: 16GB minimum
- **Disk Space**: 50GB free space
- **CPU**: 4 cores recommended
- **OS**: Linux (Ubuntu 20.04+ or similar)

### Software Requirements

```bash
# Docker
Docker version 20.10+

# Docker Compose
Docker Compose version 2.0+
```

### Install Docker & Docker Compose (if needed)

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose (if not included)
sudo apt-get update
sudo apt-get install docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

---

## 🚀 Installation

### Step 1: Clone or Download

```bash
# If you have the files, navigate to the directory
cd mini-soc

# Otherwise, create from scratch using the provided structure
```

### Step 2: Set System Parameters

```bash
# Increase vm.max_map_count for Elasticsearch
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Increase file descriptors
ulimit -n 65536
```

### Step 3: Configure Environment

```bash
# Edit .env file to change default passwords (RECOMMENDED)
nano .env

# At minimum, change these:
# - ELASTIC_PASSWORD
# - THEHIVE_SECRET
# - CORTEX_SECRET
# - MINIO_ROOT_PASSWORD
# - REDIS_PASSWORD
```

### Step 4: Start Services

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Check service status
docker compose ps
```

### Step 5: Wait for Services to Initialize

**This is important!** Services need time to start:

```bash
# Monitor startup progress
watch -n 2 'docker compose ps'

# Wait until all services show "healthy" or "running"
# This can take 5-10 minutes on first start
```

---

## ⚙️ Initial Setup

### 1. Create MinIO Bucket

```bash
# Access MinIO console at http://localhost:9003
# Login: admin / changeme123
# Create bucket: "thehive"
```

Or via CLI:

```bash
docker exec -it minio mc alias set minio http://localhost:9000 admin changeme123
docker exec -it minio mc mb minio/thehive
docker exec -it minio mc policy set download minio/thehive
```

### 2. Initialize TheHive

```bash
# Wait for TheHive to be fully started
docker compose logs thehive | grep "Started"

# Access TheHive at http://localhost:9000
# First login creates admin account
# Username: admin@thehive.local
# Password: secret (you'll be prompted to change this)
```

**Important**: On first login, create a strong admin password!

### 3. Setup Cortex

```bash
# Access Cortex at http://localhost:9001
# Click "Update Database"
# Create admin user:
#   Login: admin
#   Name: Admin
#   Password: admin123 (change in production!)

# Create organization: "demo-org"
# Create API key for TheHive integration
```

**Get Cortex API Key:**
1. Login to Cortex
2. Go to Organization → demo-org
3. Create User → Create API Key
4. Copy the API key

**Update TheHive Config:**
```bash
# Edit TheHive config
nano thehive/config/application.conf

# Replace "CORTEX_API_KEY_PLACEHOLDER" with your actual API key

# Restart TheHive
docker compose restart thehive
```

### 4. Configure Shuffle

```bash
# Access Shuffle at http://localhost:3001
# Create admin account on first access
# Username: admin@shuffle.local
# Password: (choose a strong password)
```

### 5. Setup Kibana

```bash
# Access Kibana at http://localhost:5601
# Login: elastic / changeme123

# Create index patterns:
# 1. Go to Management → Stack Management → Index Patterns
# 2. Create pattern: "logstash-*"
# 3. Select timestamp field: "@timestamp"
```

---

## 🌐 Access URLs

| Service | URL | Notes |
|---------|-----|-------|
| **Kibana** | http://localhost:5601 | Data visualization |
| **TheHive** | http://localhost:9000 | Incident response |
| **Cortex** | http://localhost:9001 | Analysis engine |
| **Shuffle** | http://localhost:3001 | Automation platform |
| **MinIO Console** | http://localhost:9003 | Object storage |
| **Elasticsearch** | http://localhost:9200 | Direct API access |
| **Logstash** | tcp://localhost:5044 | Log input (Beats) |

---

## 🔑 Default Credentials

**⚠️ CHANGE THESE IN PRODUCTION!**

### Elasticsearch / Kibana
- **Username**: `elastic`
- **Password**: `changeme123`

### TheHive
- **First Login**: `admin@thehive.local` / `secret`
- **Change password** on first login!

### Cortex
- **First Setup**: Create admin during initialization
- **Suggested**: `admin` / `admin123`

### Shuffle
- **First Setup**: Create account during initialization

### MinIO
- **Username**: `admin`
- **Password**: `changeme123`
- **Console**: http://localhost:9003

### Redis
- **Password**: `redis123`

### Cassandra
- **Username**: `cassandra`
- **Password**: `cassandra`

---

## 📚 Usage Guide

### Sending Logs to Logstash

#### Using Filebeat

```yaml
# filebeat.yml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/*.log

output.logstash:
  hosts: ["localhost:5044"]
```

#### Using Netcat (Testing)

```bash
# Send a test log
echo '{"message": "Test security event", "severity": "high"}' | nc localhost 5044
```

#### Using Python

```python
import socket
import json

log_data = {
    "message": "Failed login attempt",
    "source_ip": "192.168.1.100",
    "user": "admin"
}

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('localhost', 5044))
sock.send(json.dumps(log_data).encode() + b'\n')
sock.close()
```

### Creating TheHive Cases

1. Access TheHive: http://localhost:9000
2. Click **"New Case"**
3. Fill in details:
   - Title: "Suspicious Login Activity"
   - Severity: High
   - TLP: Amber
4. Add observables (IPs, domains, hashes)
5. Run Cortex analyzers on observables

### Running Cortex Analyzers

1. In TheHive, open a case
2. Add observable (IP, domain, hash, etc.)
3. Click on observable → **"Run Analyzers"**
4. Select analyzers (VirusTotal, AbuseIPDB, etc.)
5. View results in Reports tab

### Creating Shuffle Workflows

1. Access Shuffle: http://localhost:3001
2. Create new workflow
3. Example workflow:
   - **Trigger**: Webhook from Kibana
   - **Action 1**: Create TheHive case
   - **Action 2**: Run Cortex analyzer
   - **Action 3**: Send notification

---

## 🔄 Integration Workflows

### Workflow 1: Log → Alert → Case

```
Logstash → Elasticsearch → Kibana Alert → Shuffle → TheHive Case
```

**Setup:**
1. Create Kibana detection rule
2. Configure webhook action → Shuffle
3. Create Shuffle workflow to create TheHive case

### Workflow 2: Automated Analysis

```
TheHive Observable → Shuffle → Cortex Analyzer → Update Case
```

**Setup:**
1. Create Shuffle workflow triggered by TheHive webhook
2. Extract observables
3. Run Cortex analyzers
4. Update TheHive case with results

### Workflow 3: Threat Hunting

```
Kibana Query → Export → TheHive Investigation → Cortex Analysis
```

---

## 🔧 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker compose logs [service-name]

# Common issues:
# 1. Port conflicts
sudo netstat -tulpn | grep [port]

# 2. Insufficient memory
free -h

# 3. Elasticsearch won't start
sudo sysctl -w vm.max_map_count=262144
```

### TheHive Can't Connect to Cassandra

```bash
# Wait for Cassandra to fully initialize (can take 2-3 minutes)
docker compose logs cassandra | grep "Starting listening for CQL clients"

# Restart TheHive after Cassandra is ready
docker compose restart thehive
```

### Cortex Can't Connect to Elasticsearch

```bash
# Verify Elasticsearch is running and healthy
curl -u elastic:changeme123 http://localhost:9200/_cluster/health

# Check Cortex logs
docker compose logs cortex
```

### MinIO Bucket Not Found

```bash
# Manually create bucket
docker exec -it minio mc alias set minio http://localhost:9000 admin changeme123
docker exec -it minio mc mb minio/thehive
```

### Reset Everything

```bash
# Stop and remove all containers, networks, volumes
docker compose down -v

# Remove data directories
sudo rm -rf */data
sudo rm -rf elasticsearch/data cassandra/data

# Start fresh
docker compose up -d
```

---

## 🛡️ Security Notes

**⚠️ This setup is for LEARNING/LAB purposes only!**

### Not Production-Ready Because:

1. **Default passwords** are used
2. **No TLS/SSL** encryption between services
3. **No firewall rules** configured
4. **All services** exposed to localhost
5. **No backup strategy** implemented
6. **Single-node** deployments (no HA)

### To Make Production-Ready:

1. Change all default passwords
2. Implement TLS/SSL certificates
3. Configure proper firewall rules
4. Use secrets management (Docker secrets, Vault)
5. Implement backup procedures
6. Use reverse proxy (Nginx, Traefik)
7. Enable authentication on all services
8. Implement network segmentation
9. Regular security updates
10. Monitoring and alerting

---

## 📖 Additional Resources

### Official Documentation

- [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [TheHive](https://docs.thehive-project.org/)
- [Cortex](https://github.com/TheHive-Project/Cortex)
- [Shuffle](https://shuffler.io/docs)

### Community

- TheHive Discord: https://discord.gg/thehive-project
- Elastic Forum: https://discuss.elastic.co/

---

## 📝 License

This project is for educational purposes. Individual components have their own licenses.

---

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for improvements!

---

## ⚡ Quick Commands Cheat Sheet

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose stop

# View logs
docker compose logs -f [service-name]

# Restart a service
docker compose restart [service-name]

# Check service status
docker compose ps

# Remove everything (DESTRUCTIVE)
docker compose down -v

# Update services
docker compose pull
docker compose up -d

# Access service shell
docker compose exec [service-name] bash
```

---

**Built with ❤️ for Security Operations Learning**