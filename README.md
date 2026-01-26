# 🛡️ Mini-SOC — Open‑Source Security Operations Center

Mini‑SOC is a **fully functional, educational and reproducible SOC laboratory**, designed to demonstrate **how a modern Security Operations Center actually works**, end‑to‑end, using **only open‑source technologies**.

This repository is meant to be:

* easy to understand for beginners,
* detailed enough for cybersecurity students and SOC analysts,
* clean and professional for GitHub, reports, and technical evaluations.

---

## 1. Project Goals

The main goals of this project are:

* Build a **real SOC pipeline**: from logs to incidents
* Understand the **role of each SOC technology**
* Simulate **realistic cyber‑attack scenarios**
* Detect threats using **Elastic Security (SIEM)**
* Manage alerts and incidents using **TheHive**
* Enrich investigations with **Cortex** and **MISP**
* Prepare the ground for **SOAR automation (Shuffle)**

This project is suitable for:

* SOC / Blue Team learning
* PFA / PFE projects
* cybersecurity labs and demos
* hands‑on SOC training

---

## 2. Global Architecture

### 2.1 Logical SOC Architecture

```
Log Sources / Simulated Attacks
        │
        ▼
    Logstash
        │
        ▼
 Elasticsearch  ───►  Kibana (Elastic Security)
        │
        ▼
  Sync Service (Elastic → TheHive)
        │
        ▼
      TheHive
     ▲        ▲
     │        │
  Cortex     MISP

(All services are deployed using Docker Compose)
```

<img width="2688" height="1600" alt="archi" src="https://github.com/user-attachments/assets/61c061ec-5fc7-4478-b7d8-1be7634ff2c0" />


### 2.2 SOC Workflow

1. **Log generation / collection** (simulated attacks or logs)
2. **Ingestion & normalization** (Logstash)
3. **Detection & correlation** (Elastic Security rules)
4. **Alert creation** (Elastic SIEM)
5. **Alert synchronization** (custom sync service)
6. **Incident management** (TheHive)
7. **Enrichment & intelligence** (Cortex, MISP)
8. **Automation (optional)** (Shuffle)

---

## 3. Technology Stack and Their Importance

| Technology               | Why it is used                                             |
| ------------------------ | ---------------------------------------------------------- |
| **Elasticsearch (7.17)** | Core SIEM engine: indexing, search, correlation, detection |
| **Kibana**               | SOC interface: dashboards, detections, alerts              |
| **Elastic Security**     | SIEM detection rules and alerting                          |
| **Logstash**             | Log ingestion and normalization                            |
| **TheHive 5**            | Incident & case management platform                        |
| **Cortex**               | Automated IOC analysis (IP, hash, domain, URL)             |
| **MISP**                 | Threat Intelligence sharing and correlation                |
| **Shuffle**              | SOAR automation platform                                   |
| **Cassandra**            | Database backend for TheHive                               |
| **MinIO**                | Object storage (attachments, artifacts)                    |
| **Redis**                | Cache and internal queues                                  |

---

## 4. Repository Structure

```
mini-soc/
├── docker-compose.yml          # Full SOC orchestration
├── .env                        # Environment variables (secrets)
├── Dockerfile.sync             # Sync service image
│
├── elasticsearch/              # Elasticsearch configuration
├── kibana/                     # Kibana configuration
├── logstash/                   # Logstash pipelines
│
├── thehive/                    # TheHive configuration
├── cortex/                     # Cortex configuration
├── misp/                       # MISP configuration
├── shuffle/                    # Shuffle configuration
│
├── cassandra/                  # Cassandra data
├── redis/                      # Redis
├── minio/                      # MinIO storage
│
├── sync.py                     # Elastic → TheHive synchronization
├── mini_soc_alert_generator.py # Attack & log generator
├── create_elastic_alerts.py    # Simple Elastic alert test
├── create_visible_alert.sh     # Bash alert injection
│
├── architecture.txt            # ASCII architecture diagram
├── configure-cortex.md         # Cortex setup guide
└── exec.txt                    # Useful commands & fixes
```

---

## 5. Requirements

* Linux (tested on Kali Linux)
* Docker ≥ 24
* Docker Compose v2
* Minimum 8 GB RAM (16 GB recommended)

---

## 6. Security Notice (Very Important)

⚠️ This project is a **laboratory environment**.

Default passwords and API keys **must NOT** be used in production.

You **must**:

* change all default passwords
* generate **dedicated API keys**
* use **separate users and roles** for each service
* update API keys **directly inside the code** (`sync.py`, scripts)

---

## 7. Users, Roles and API Keys

### 7.1 Elasticsearch / Kibana

Recommended users:

* `elastic` → administrator
* `kibana_system` → Kibana service user
* `thehive_user` → API access for TheHive

Example:

```json
POST /_security/user/thehive_user
{
  "password": "CHANGE_ME",
  "roles": ["superuser"]
}
```

### 7.2 TheHive

Create:

* an **admin user**
* SOC **analyst users**
* a **dedicated API key** for the sync service

⚠️ TheHive API key **must be updated in `sync.py`**.

### 7.3 Cortex

* Generate a Cortex API key
* Register Cortex inside TheHive (Admin → Cortex servers)

### 7.4 MISP

* Change default admin password
* Generate API keys if advanced integration is needed

---

## 8. Network Ports

| Service       | Port         |
| ------------- | ------------ |
| Elasticsearch | 9200         |
| Kibana        | 5601         |
| TheHive       | 9000         |
| Cortex        | 9001         |
| MISP          | 8443 (HTTPS) |
| MinIO         | 9000 / 9001  |
| Shuffle       | 3001         |
| Redis         | 6379         |
| Cassandra     | 9042         |

---

## 9. Deployment

```bash
git clone https://github.com/IsMah01/.....
cd mini-soc

docker compose up -d
```

Initial startup may take several minutes (Elastic + Cassandra).

---

## 10. Attack & Alert Simulation

The script `mini_soc_alert_generator.py` injects **realistic ECS‑like logs** to trigger detections.

Examples:

```bash
python3 mini_soc_alert_generator.py --scenario ssh_bruteforce
python3 mini_soc_alert_generator.py --scenario reverse_shell
python3 mini_soc_alert_generator.py --scenario win_powershell
python3 mini_soc_alert_generator.py --scenario all
```

Alerts will appear in:
**Kibana → Security → Alerts**

---

## 11. Elastic → TheHive Synchronization

The `sync.py` service:

* fetches Elastic SIEM alerts
* prevents duplicates
* creates alerts in TheHive automatically

⚠️ Always change API keys before sharing the project publicly.

---

## 12. Enrichment with Cortex and MISP

* Cortex performs automatic analysis on observables
* MISP provides global threat intelligence context

See: `configure-cortex.md`

---

## 13. SOAR Automation (Shuffle)

Shuffle is included to demonstrate:

* automated case creation
* notifications
* response actions

---

## 14. Common Issues

### Elasticsearch flood‑stage (read‑only indices)

```bash
curl -u elastic:changeme123 -X PUT localhost:9200/_all/_settings \
  -H 'Content-Type: application/json' \
  -d '{"index.blocks.read_only_allow_delete": null}'
```

---

## 15. Author

**Ismail Mahmoudi**
Cybersecurity Student — ENSIAS

---

## 16. License

Educational open‑source project. Free to use, modify and extend.
