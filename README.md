# 🛡️ Mini-SOC — Open‑Source Security Operations Center (Elastic • TheHive • Cortex • MISP • Shuffle)

Ce dépôt contient un **Mini‑SOC complet, pédagogique et opérationnel**, conçu pour être **facile à comprendre, facile à déployer et facile à étendre**.

L’objectif est de montrer **comment fonctionne réellement un SOC moderne**, depuis la collecte des logs jusqu’à l’investigation et l’enrichissement des incidents, en s’appuyant **uniquement sur des technologies open‑source**.

---

## 📌 Objectifs du projet

* Construire un **SOC fonctionnel de bout en bout**
* Comprendre le rôle **précis** de chaque brique SOC
* Simuler des **attaques réalistes** (SSH brute force, C2, PowerShell, exfiltration…)
* Détecter via **Elastic Security**
* Centraliser et investiguer dans **TheHive**
* Enrichir avec **Cortex** et **MISP**
* Préparer l’automatisation **SOAR avec Shuffle**

Ce projet est destiné à :

* étudiants en cybersécurité
* projets PFA / PFE
* formations SOC / Blue Team
* démonstrations techniques

---

## 🧱 Architecture générale du Mini‑SOC

### 🔄 Vue logique globale

```
Sources de logs
   │
   ▼
Logstash ──► Elasticsearch ──► Kibana (Elastic Security)
                            │
                            ▼
                     Service de synchronisation
                            │
                            ▼
                         TheHive
                       ▲           ▲
                       │           │
                    Cortex        MISP

           (ensemble orchestré via Docker Compose)
```

### 🧠 Logique SOC

1. **Collecte** : les événements de sécurité sont générés ou injectés
2. **Détection** : Elastic Security applique des règles
3. **Alerte** : création d’alertes dans Elastic
4. **Orchestration** : synchronisation vers TheHive
5. **Investigation** : analyste SOC traite l’incident
6. **Enrichissement** : Cortex & MISP ajoutent du contexte
7. **Automatisation (optionnelle)** : Shuffle

---

## 🧰 Stack technique et importance de chaque brique

| Technologie              | Rôle clé dans le SOC                                           |
| ------------------------ | -------------------------------------------------------------- |
| **Elasticsearch (7.17)** | Moteur central : indexation, recherche, corrélation, détection |
| **Kibana**               | Interface SOC : visualisation, règles, alertes                 |
| **Logstash**             | Ingestion et normalisation des logs                            |
| **Elastic Security**     | Moteur SIEM (règles, corrélations)                             |
| **TheHive 5**            | Gestion des alertes et des incidents                           |
| **Cortex**               | Analyse automatique des IOC (IP, hash, URL…)                   |
| **MISP**                 | Threat Intelligence et corrélation globale                     |
| **Shuffle**              | SOAR : automatisation des réponses                             |
| **Cassandra**            | Base de données TheHive                                        |
| **MinIO**                | Stockage d’artefacts (preuves, fichiers)                       |
| **Redis**                | Cache et files internes                                        |

---

## 📁 Structure du projet

```
mini-soc/
├── docker-compose.yml          # Orchestration complète du SOC
├── .env                        # Variables d’environnement (⚠️ secrets)
├── Dockerfile.sync             # Image du service Elastic → TheHive
│
├── elasticsearch/              # Configuration Elasticsearch
├── kibana/                     # Configuration Kibana
├── logstash/                   # Pipelines Logstash
│
├── thehive/                    # Configuration TheHive
├── cortex/                     # Configuration Cortex
├── misp/                       # Configuration MISP
├── shuffle/                    # Configuration Shuffle
│
├── cassandra/                  # Données Cassandra
├── redis/                      # Redis
├── minio/                      # MinIO
│
├── sync.py                     # 🔁 Synchronisation Elastic → TheHive
├── mini_soc_alert_generator.py # 🎯 Génération d’attaques simulées
├── create_elastic_alerts.py    # Alerte simple de test
├── create_visible_alert.sh     # Script bash de test
│
├── architecture.txt            # Schéma ASCII
├── configure-cortex.md         # Guide configuration Cortex
└── exec.txt                    # Commandes utiles & dépannage
```

---

## ⚙️ Pré‑requis

* Linux (testé sur Kali Linux)
* Docker ≥ 24
* Docker Compose v2
* RAM : **8 Go minimum (16 Go recommandé)**

---

## 🔐 Sécurité & bonnes pratiques (IMPORTANT)

⚠️ **Ce projet est un laboratoire**. Par défaut, des mots de passe simples sont utilisés.

👉 **En production ou pour une soutenance sérieuse** :

* changer tous les mots de passe
* générer des **API keys dédiées**
* utiliser des **rôles et utilisateurs séparés**

---

## 🔑 Gestion des utilisateurs & rôles

### Elasticsearch / Kibana

Créer des utilisateurs dédiés :

* `elastic` : admin
* `kibana_system` : service Kibana
* `thehive_user` : accès API vers Elastic

Exemple :

```bash
POST /_security/user/thehive_user
{
  "password": "CHANGE_ME",
  "roles": ["superuser"]
}
```

### TheHive

Créer :

* un **admin**
* un ou plusieurs **analystes SOC**
* générer une **API key par service**

👉 L’API key **doit être changée dans le code** (`sync.py`).

### Cortex

* Générer une **API key Cortex**
* L’ajouter dans TheHive (Admin → Cortex)

### MISP

* Changer l’admin password
* Générer une **API key MISP** si intégration avancée

---

## 🌐 Ports utilisés

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

## 🚀 Déploiement

```bash
git clone https://github.com/your-org/mini-soc.git
cd mini-soc

docker compose up -d
```

⏳ Premier démarrage : 3 à 5 minutes.

---

## 🧪 Génération de scénarios d’attaque

Le script `mini_soc_alert_generator.py` permet de **simuler des attaques réalistes**.

Exemples :

```bash
python3 mini_soc_alert_generator.py --scenario ssh_bruteforce
python3 mini_soc_alert_generator.py --scenario reverse_shell
python3 mini_soc_alert_generator.py --scenario win_powershell
python3 mini_soc_alert_generator.py --scenario all
```

👉 Les alertes apparaissent dans :
**Kibana → Security → Alerts**

---

## 🔁 Synchronisation Elastic → TheHive

Le service `sync.py` :

* récupère les alertes Elastic
* évite les doublons
* crée automatiquement des alertes TheHive

⚠️ **Changer l’API key TheHive dans le code avant usage public**.

---

## 🧠 Enrichissement (Cortex & MISP)

* Cortex analyse automatiquement IP, hash, URL
* MISP apporte du contexte Threat Intelligence

Voir : `configure-cortex.md`

---

## 🤖 Automatisation (Shuffle)

Shuffle est prêt pour :

* création automatique de cases
* notifications
* blocage IP
* enrichissement automatique

---

## 🧯 Dépannage courant

### Indices en read‑only (flood stage)

```bash
curl -u elastic:changeme123 -X PUT localhost:9200/_all/_settings \
  -H 'Content-Type: application/json' \
  -d '{"index.blocks.read_only_allow_delete": null}'
```

---

## 🎓 Auteur

**Ismail Mahmoudi**
Cybersecurity Student — ENSIAS

---

## 📄 Licence

Projet éducatif open‑source. Libre à adapter, améliorer et étendre.
