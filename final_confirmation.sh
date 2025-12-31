#!/bin/bash
echo "=== CONFIRMATION FINALE SYNCHRONISATION ==="
echo

# Créer une alerte avec un nom unique
UNIQUE_ID="final-confirm-$(date +%s)"
echo "1. 🚨 Création alerte de confirmation unique :"
curl -s -u elastic:changeme123 -X POST "http://localhost:9200/.siem-signals-default-000001/_doc" \
  -H 'Content-Type: application/json' \
  -d '{
    "@timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
    "signal": {
      "rule": {
        "id": "'"$UNIQUE_ID"'",
        "name": "[CONFIRMATION FINALE] Sync Elastic→TheHive OK",
        "description": "Cette alerte confirme que la synchronisation fonctionne",
        "severity": 2
      }
    },
    "host": {"name": "confirmation-server"},
    "event": {"category": "confirmation"}
  }' | jq -r '"   ✅ Créée - ID Elastic: \(._id)"'

echo -e "\n2. ⏳ Attente traitement (40s)..."
sleep 40

echo -e "\n3. 📋 Logs synchronisation :"
docker-compose logs --tail=10 elastic-thehive-sync | grep -E "(Nouvelle|✓|Cycle.*démarré)"

echo -e "\n4. 🔍 Instructions vérification :"
echo "   a. Allez sur : http://localhost:9000"
echo "   b. Connectez-vous : admin@thehive.local / secret"
echo "   c. Cherchez l'alerte : '[CONFIRMATION FINALE] Sync Elastic→TheHive OK'"
echo "   d. Si elle est visible → ✅ TOUT FONCTIONNE !"
echo
echo "5. 💾 État synchronisation :"
docker-compose exec elastic-thehive-sync cat /data/sync_state.json 2>/dev/null | \
  jq -r '"   Alertes traitées: \(.total_processed)\n   Dernière mise à jour: \(.updated[11:19])"' 2>/dev/null
