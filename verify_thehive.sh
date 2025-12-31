#!/bin/bash
echo "=== VÉRIFICATION THÉHIVE COMPLÈTE ==="
echo

# 1. Toutes les alertes (sans filtre)
echo "1. 📊 Toutes les alertes TheHive:"
curl -s "http://localhost:9000/api/alert" \
  -H "Authorization: Bearer iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD" | \
  jq -r 'length as $count | "   Total: \($count) alertes"'

# 2. Alertes récentes (dernières 10 minutes)
echo -e "\n2. 🔍 Alertes récentes (10min):"
curl -s "http://localhost:9000/api/alert?range=last10m" \
  -H "Authorization: Bearer iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD" | \
  jq -r '.[] | "   [\(.date | todate)] \(.title)"'

# 3. Chercher par source Elastic
echo -e "\n3. 🎯 Alertes source 'Elastic Security':"
curl -s "http://localhost:9000/api/alert" \
  -H "Authorization: Bearer iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD" | \
  jq -r '.[] | select(.source == "Elastic Security") | "   ✅ \(.title) (ID: \(.id))"'

# 4. Vérifier la dernière alerte créée
echo -e "\n4. 📅 Dernière alerte créée:"
curl -s "http://localhost:9000/api/alert?range=last5m" \
  -H "Authorization: Bearer iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD" | \
  jq -r 'max_by(.date) | "   Titre: \(.title)\n   Date: \(.date | todate)\n   Source: \(.source)\n   ID: \(.id)"'

# 5. Vérifier avec l'interface web
echo -e "\n5. 🌐 Interface web:"
echo "   TheHive: http://localhost:9000"
echo "   (Connectez-vous avec admin@thehive.local:secret)"
