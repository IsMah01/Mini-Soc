#!/usr/bin/env python3
"""
Script de synchronisation Elastic → TheHive
Simple, robuste, avec gestion des erreurs
"""

import os
import sys
import time
import json
import hashlib
import requests
from datetime import datetime
from base64 import b64encode

# ============================================================================
# CONFIGURATION
# ============================================================================

# Configuration depuis variables d'environnement
CONFIG = {
    'elastic_host': os.getenv('ELASTIC_HOST', 'http://elasticsearch:9200'),
    'elastic_user': os.getenv('ELASTIC_USER', 'elastic'),
    'elastic_password': os.getenv('ELASTIC_PASSWORD', 'changeme123'),
    'thehive_url': os.getenv('THEHIVE_URL', 'http://thehive:9000/api/alert'),
    'thehive_key': os.getenv('THEHIVE_API_KEY', 'iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD'),
    'siem_index': '.siem-signals-default-000001',
    'state_file': '/data/sync_state.json',
    'check_interval': 30,  # secondes
    'lookback_minutes': 5   # minutes
}

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

def log(msg, level="INFO"):
    """Logging simple et clair"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [{level}] {msg}", flush=True)

def get_elastic_headers():
    """Headers pour Elastic avec authentification Basic"""
    auth = b64encode(f"{CONFIG['elastic_user']}:{CONFIG['elastic_password']}".encode()).decode()
    return {
        'Content-Type': 'application/json',
        'Authorization': f'Basic {auth}'
    }

def get_thehive_headers():
    """Headers pour TheHive avec API key"""
    thehive_key = CONFIG['thehive_key']
    return {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {thehive_key}'
    }

def generate_fingerprint(alert):
    """Générer un fingerprint unique pour éviter les doublons TheHive"""
    source = alert['_source']
    rule = source.get('signal', {}).get('rule', {})
    timestamp = source.get('@timestamp', '')
    
    # Créer un hash unique basé sur l'ID, la règle et le timestamp
    data = f"{alert['_id']}:{rule.get('id', '')}:{timestamp}"
    return hashlib.md5(data.encode()).hexdigest()[:16]

def load_state():
    """Charger l'état des alertes déjà traitées"""
    try:
        with open(CONFIG['state_file'], 'r') as f:
            state = json.load(f)
            processed_ids = set(state.get('processed_ids', []))
            log(f"État chargé: {len(processed_ids)} alertes déjà traitées")
            return processed_ids
    except FileNotFoundError:
        log("Nouvel état: fichier non trouvé, démarrage à zéro")
        return set()
    except json.JSONDecodeError as e:
        log(f"Erreur lecture état: {e}, démarrage à zéro", "WARNING")
        return set()
    except Exception as e:
        log(f"Erreur inattendue lecture état: {e}", "ERROR")
        return set()

def save_state(processed_ids):
    """Sauvegarder l'état"""
    try:
        state = {
            'processed_ids': list(processed_ids),
            'updated': datetime.now().isoformat(),
            'total_processed': len(processed_ids)
        }
        with open(CONFIG['state_file'], 'w') as f:
            json.dump(state, f, indent=2)
        log(f"État sauvegardé: {len(processed_ids)} alertes")
    except Exception as e:
        log(f"Erreur sauvegarde état: {e}", "ERROR")

def test_connections():
    """Tester les connexions aux services"""
    log("Test des connexions...")
    
    # Test Elasticsearch
    try:
        headers = get_elastic_headers()
        url = f"{CONFIG['elastic_host']}/_cat/health?format=json"
        resp = requests.get(url, headers=headers, timeout=10)
        if resp.status_code == 200:
            health = resp.json()[0]
            log(f"Elastic: ✓ ({health['status']})")
        else:
            log(f"Elastic: ✗ HTTP {resp.status_code}", "ERROR")
            return False
    except Exception as e:
        log(f"Elastic: ✗ {e}", "ERROR")
        return False
    
    # Test TheHive
    try:
        headers = get_thehive_headers()
        resp = requests.get(f"{CONFIG['thehive_url']}?range=last5m", headers=headers, timeout=10)
        if resp.status_code == 200:
            log("TheHive: ✓")
        else:
            log(f"TheHive: ✗ HTTP {resp.status_code}", "ERROR")
            return False
    except Exception as e:
        log(f"TheHive: ✗ {e}", "ERROR")
        return False
    
    return True

def fetch_elastic_alerts():
    """Récupérer les alertes récentes d'Elastic"""
    query = {
        "query": {
            "bool": {
                "must": [{"exists": {"field": "signal.rule"}}],
                "filter": [
                    {
                        "range": {
                            "@timestamp": {
                                "gte": f"now-{CONFIG['lookback_minutes']}m",
                                "lte": "now"
                            }
                        }
                    }
                ]
            }
        },
        "sort": [{"@timestamp": {"order": "desc"}}],
        "size": 20  # Réduit pour éviter trop de requêtes
    }
    
    try:
        headers = get_elastic_headers()
        url = f"{CONFIG['elastic_host']}/{CONFIG['siem_index']}/_search"
        resp = requests.post(url, headers=headers, json=query, timeout=15)
        
        if resp.status_code == 200:
            data = resp.json()
            alerts = data.get('hits', {}).get('hits', [])
            total = data.get('hits', {}).get('total', {}).get('value', 0)
            log(f"Elastic: {len(alerts)} alertes récentes ({total} total)")
            return alerts
        else:
            log(f"Elastic: Erreur HTTP {resp.status_code}", "WARNING")
            return []
            
    except Exception as e:
        log(f"Elastic: Erreur {e}", "WARNING")
        return []

def create_thehive_alert(elastic_alert, fingerprint):
    """Créer une alerte TheHive à partir d'une alerte Elastic"""
    source = elastic_alert['_source']
    rule = source.get('signal', {}).get('rule', {})
    alert_id = elastic_alert['_id']
    
    # Convertir la date
    try:
        timestamp = source['@timestamp']
        if 'T' in timestamp:
            date_obj = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            date_ms = int(date_obj.timestamp() * 1000)
        else:
            date_ms = int(time.time() * 1000)
    except:
        date_ms = int(time.time() * 1000)
    
    # Construire l'alerte TheHive avec fingerprint unique
    return {
        "type": "elastic_siem",
        "source": "Elastic Security",
        "sourceRef": f"{alert_id}:{fingerprint}",  # Unique avec fingerprint
        "title": rule.get('name', 'Alerte Elastic')[:150],
        "description": f"""**Alerte Elastic Security**

**Règle:** {rule.get('name', 'Inconnu')}
**Description:** {rule.get('description', 'Pas de description')}

**Détails:**
- ID Elastic: {alert_id}
- Timestamp: {source.get('@timestamp', 'Inconnu')}
- Sévérité: {source.get('signal', {}).get('severity', 2)}

**Source:** {CONFIG['elastic_host']}
**Importé automatiquement le:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}""",
        "severity": source.get('signal', {}).get('severity', 2),
        "date": date_ms,
        "tags": ["elastic", "security", "auto-import", "siem"],
        "tlp": 2,
        "pap": 2
    }

def send_to_thehive(thehive_alert):
    """Envoyer une alerte à TheHive"""
    try:
        headers = get_thehive_headers()
        resp = requests.post(CONFIG['thehive_url'], headers=headers, json=thehive_alert, timeout=15)
        
        if resp.status_code in [200, 201]:
            return True, None
        elif resp.status_code == 400:
            # Analyser l'erreur
            try:
                error_data = resp.json()
                if "already exists" in str(error_data):
                    return False, "Already exists in TheHive"
                else:
                    return False, f"HTTP 400: {error_data.get('message', 'Unknown error')}"
            except:
                return False, f"HTTP 400: {resp.text[:100]}"
        else:
            return False, f"HTTP {resp.status_code}: {resp.text[:100]}"
            
    except Exception as e:
        return False, str(e)

# ============================================================================
# FONCTION PRINCIPALE
# ============================================================================

def main():
    """Fonction principale"""
    log("=" * 60)
    log("🚀 SYNC ELASTIC → THEHIVE - DÉMARRAGE")
    log("=" * 60)
    
    # Afficher la configuration
    log(f"Configuration:")
    log(f"  Elastic: {CONFIG['elastic_host']}")
    log(f"  TheHive: {CONFIG['thehive_url']}")
    log(f"  Index: {CONFIG['siem_index']}")
    log(f"  Intervalle: {CONFIG['check_interval']}s")
    log(f"  Recherche: {CONFIG['lookback_minutes']} minutes")
    log("=" * 60)
    
    # Test initial des connexions
    if not test_connections():
        log("Connexions échouées. Arrêt.", "ERROR")
        sys.exit(1)
    
    # Charger l'état
    processed_ids = load_state()
    
    # Boucle principale
    cycle = 0
    while True:
        cycle += 1
        log(f"Cycle #{cycle} démarré")
        
        try:
            # Récupérer les alertes récentes
            alerts = fetch_elastic_alerts()
            
            if alerts:
                new_alerts = 0
                sent_alerts = 0
                errors = []
                
                for alert in alerts:
                    alert_id = alert['_id']
                    fingerprint = generate_fingerprint(alert)
                    
                    if alert_id not in processed_ids:
                        new_alerts += 1
                        rule_name = alert['_source'].get('signal', {}).get('rule', {}).get('name', 'Inconnu')
                        
                        log(f"Nouvelle alerte #{new_alerts}: {rule_name[:60]}")
                        log(f"  Fingerprint: {fingerprint}")
                        
                        # Créer et envoyer l'alerte TheHive
                        thehive_alert = create_thehive_alert(alert, fingerprint)
                        success, error = send_to_thehive(thehive_alert)
                        
                        if success:
                            processed_ids.add(alert_id)
                            sent_alerts += 1
                            log(f"  ✓ Envoyée à TheHive")
                        else:
                            if "already exists" in error:
                                log(f"  ⏭️  Déjà dans TheHive, ajoutée à l'état")
                                processed_ids.add(alert_id)  # Marquer comme traitée quand même
                            else:
                                log(f"  ✗ Erreur: {error}", "WARNING")
                                errors.append(error)
                    else:
                        # Silencieux pour les doublons
                        pass
                
                # Sauvegarder si changements
                if new_alerts > 0:
                    save_state(processed_ids)
                    log(f"Résumé: {sent_alerts}/{new_alerts} envoyées avec succès")
                    if errors:
                        log(f"Erreurs rencontrées: {len(errors)}", "WARNING")
            
            else:
                log("Aucune nouvelle alerte détectée")
            
        except KeyboardInterrupt:
            log("Arrêt manuel demandé", "INFO")
            break
        except Exception as e:
            log(f"Erreur inattendue: {e}", "ERROR")
            import traceback
            traceback.print_exc()
        
        # Attente avant prochain cycle
        log(f"Attente de {CONFIG['check_interval']} secondes...")
        time.sleep(CONFIG['check_interval'])

# ============================================================================
# POINT D'ENTRÉE
# ============================================================================

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("Script arrêté par l'utilisateur", "INFO")
    except Exception as e:
        log(f"Erreur fatale: {e}", "ERROR")
        import traceback
        traceback.print_exc()
        sys.exit(1)
