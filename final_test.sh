#!/bin/bash
echo "=== TEST FINAL SYNCHRONISATION ==="
echo "Heure: $(date)"
echo

# 1. État
echo "1. 📊 État service:"
docker-compose ps elastic-thehive-sync

# 2. Vérifier permissions
echo -e "\n2. 🔐 Permissions /data:"
docker-compose exec elastic-thehive-sync ls -la /data/

# 3. Créer alerte test
echo -e "\n3. 🚨 Création alerte test..."
ALERT_ID="final-test-$(date +%s)"
curl -s -u elastic:changeme123 -X POST "http://localhost:9200/.siem-signals-default-000001/_doc" \
  -H 'Content-Type: application/json' \
  -d '{
    "@timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
    "signal": {
      "rule": {
        "id": "'"$ALERT_ID"'",
        "name": "[FINAL TEST] Synchronisation opérationnelle",
        "description": "Test final de la synchronisation Elastic → TheHive",
        "severity": 2
      }
    },
    "host": {"name": "final-test-server"},
    "event": {"category": "malware", "action": "execution"}
  }' | jq -r '"   ID Elastic: \(._id)"'

# 4. Attendre synchronisation
echo -e "\n4. ⏳ Attente synchronisation (35s)..."
sleep 35

# 5. Vérifier logs
echo -e "\n5. 📋 Logs synchronisation:"
docker-compose logs --tail=10 elastic-thehive-sync | grep -A5 "Cycle"

# 6. Vérifier TheHive
echo -e "\n6. 📊 Vérification TheHive (dernières 2 min):"
curl -s "http://localhost:9000/api/alert?range=last2m" \
  -H "Authorization: Bearer iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD" | \
  jq -r '.[] | "   \(.title) - \(.date | todate)"' | head -5

# 7. Vérifier état sauvegardé
echo -e "\n7. 💾 État sauvegardé:"
docker-compose exec elastic-thehive-sync cat /data/sync_state.json 2>/dev/null | \
  jq -r '"   Alertes traitées: \(.total_processed)\n   Dernière maj: \(.updated)"' 2>/dev/null || \
  echo "   Pas encore d'état"

echo -e "\n✅ Test final terminé"
