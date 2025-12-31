#!/bin/bash
echo "=== DÉBUGAGE THÉHIVE ==="
echo

# 1. Vérifier la configuration TheHive
echo "1. 🔧 Configuration TheHive:"
curl -s "http://localhost:9000/api/status" \
  -H "Authorization: Bearer iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD" | \
  jq -r '.config | "   Version: \(.version)\n   Organisation: \(.organisation)"'

# 2. Vérifier les alertes avec différents filtres
echo -e "\n2. 🔍 Toutes les alertes (sans filtre de date):"
curl -s "http://localhost:9000/api/alert" \
  -H "Authorization: Bearer iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD" | \
  jq '.[] | {id, title, source, date: (.date | todate), status}' | head -5

# 3. Chercher spécifiquement nos alertes de test
echo -e "\n3. 🎯 Recherche alertes 'STRESS TEST':"
curl -s "http://localhost:9000/api/alert" \
  -H "Authorization: Bearer iWtYr7XOrugw5HqUKg4HvXizcL7CV+qD" | \
  jq -r '.[] | select(.title | contains("STRESS")) | "   \(.title) - \(.date | todate)"'

# 4. Vérifier dans l'interface web
echo -e "\n4. 🌐 Accès web:"
echo "   TheHive: http://localhost:9000"
echo "   Identifiants: admin@thehive.local / secret"
echo "   (Vérifiez dans l'interface si les alertes apparaissent)"

# 5. Vérifier si c'est un problème de date
echo -e "\n5. ⏰ Problème de date possible:"
echo "   Les dates dans TheHive semblent très anciennes (année 57968!)"
echo "   Cela pourrait être un bug de conversion de timestamp"
