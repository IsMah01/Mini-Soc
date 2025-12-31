#!/bin/bash
echo "=== TEST DE CHARGE SYNCHRONISATION ==="
echo "Création de 5 alertes simultanées..."
echo

for i in {1..5}; do
    (
        ALERT_NAME="[STRESS TEST $i] Test de charge synchronisation"
        curl -s -u elastic:changeme123 -X POST "http://localhost:9200/.siem-signals-default-000001/_doc" \
          -H 'Content-Type: application/json' \
          -d "{
            \"@timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")\",
            \"signal\": {
              \"rule\": {
                \"id\": \"stress-test-$i-$(date +%s)\",
                \"name\": \"$ALERT_NAME\",
                \"description\": \"Test de charge #$i de la synchronisation\",
                \"severity\": $((i % 3 + 1))
              }
            },
            \"host\": {\"name\": \"server-$i\"},
            \"event\": {\"category\": \"stress-test\"}
          }" > /dev/null
        echo "   ✅ Alerte $i créée: $ALERT_NAME"
    ) &
    sleep 1  # Petit délai entre chaque création
done

wait

echo -e "\n⏳ Attente de 90 secondes pour traitement complet..."
sleep 90

echo -e "\n📊 Résultats:"
echo "   Logs synchronisation:"
docker-compose logs --tail=20 elastic-thehive-sync | grep -E "(Nouvelle|✓|Cycle.*démarré|Résumé)"

echo -e "\n💾 État final:"
docker-compose exec elastic-thehive-sync cat /data/sync_state.json 2>/dev/null | \
  jq -r '"   Alertes traitées: \(.total_processed)\n   Dernière maj: \(.updated)"' 2>/dev/null
