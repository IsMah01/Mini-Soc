#!/bin/bash
echo "=== TEST RAPIDE SYNCHRONISATION ==="

# 1. Vérifier l'état
echo -e "\n1. 📦 État conteneur:"
docker-compose ps elastic-thehive-sync

# 2. Voir les logs
echo -e "\n2. 📋 Logs récentes:"
docker-compose logs --tail=10 elastic-thehive-sync | tail -5

# 3. Créer alerte test
echo -e "\n3. 🚨 Création alerte:"
ALERT_ID="quick-test-$(date +%s)"
curl -s -u elastic:changeme123 -X POST "http://localhost:9200/.siem-signals-default-000001/_doc" \
  -H 'Content-Type: application/json' \
  -d '{
    "@timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")'",
    "signal": {
      "rule": {
        "id": "'"$ALERT_ID"'",
        "name": "[QUICK TEST] Test rapide synchronisation",
        "description": "Test rapide après correction syntaxe",
        "severity": 2
      }
    }
  }' | jq -r '"   ID: \(._id)"'

# 4. Attendre et vérifier
echo -e "\n4. ⏳ Attente 40s..."
sleep 40

# 5. Vérifier dans TheHive
echo -e "\n5. 📊 Vérification TheHive:"
curl -s "http://localhost:9000/api/alert?range=last2m" \
  -H "Authorization: Bearer iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD" | \
  jq -r '.[] | select(.title | contains("QUICK TEST")) | "   ✅ Trouvée: \(.title)"'

echo -e "\n✅ Test terminé"
