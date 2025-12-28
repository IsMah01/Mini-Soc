from elasticsearch import Elasticsearch
import requests
import json

# CONFIG
ELASTIC_URL = "http://localhost:9200"
ELASTIC_USER = "elastic"
ELASTIC_PASS = "changeme123"
INDEX = "thehive-alerts"

THEHIVE_URL = "http://localhost:9000"
THEHIVE_API_KEY = "iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD"

es = Elasticsearch(
    ELASTIC_URL,
    basic_auth=(ELASTIC_USER, ELASTIC_PASS)
)

headers = {
    "Authorization": f"Bearer {THEHIVE_API_KEY}",
    "Content-Type": "application/json"
}

# Get unprocessed alerts
query = {
    "query": {
        "bool": {
            "must_not": {
                "term": { "status": "processed" }
            }
        }
    }
}

alerts = es.search(index=INDEX, body=query, size=10)["hits"]["hits"]

for alert in alerts:
    src = alert["_source"]

    case_title = f"SSH brute-force on {src.get('host', 'unknown')}"
    description = f"""
Rule: {src.get('rule_name')}
Host: {src.get('host')}
User: {src.get('user')}
Source IP: {src.get('source_ip')}
"""

    case_payload = {
        "title": case_title,
        "description": description,
        "severity": 2,
        "tlp": 2,
        "tags": ["elastic", "ssh", "bruteforce"]
    }

    r = requests.post(
        f"{THEHIVE_URL}/api/v1/case",
        headers=headers,
        data=json.dumps(case_payload)
    )

    if r.status_code == 201:
        es.update(
            index=INDEX,
            id=alert["_id"],
            body={"doc": {"status": "processed"}}
        )
        print(f"[+] Case created: {case_title}")
    else:
        print(f"[!] Failed to create case: {r.text}")

