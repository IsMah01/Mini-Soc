#!/bin/bash
echo "=== DÉPLOIEMENT SYNCHRONISATION ELASTIC-THEHIVE ==="
echo

# 1. Arrêter et supprimer l'ancien service
echo "1. Nettoyage ancien service..."
docker-compose stop elastic-thehive-sync 2>/dev/null || true
docker-compose rm -f elastic-thehive-sync 2>/dev/null || true

# 2. Supprimer le volume (optionnel - commenter pour garder les données)
# echo "2. Nettoyage volume..."
# docker volume rm -f mini-soc_elastic-thehive-sync-data 2>/dev/null || true

# 3. Construire l'image
echo "3. Construction image..."
docker-compose build elastic-thehive-sync

# 4. Démarrer le service
echo "4. Démarrage service..."
docker-compose up -d elastic-thehive-sync

# 5. Attendre et vérifier
echo "5. Vérification..."
sleep 10

echo -e "\n📊 ÉTAT ACTUEL:"
docker-compose ps elastic-thehive-sync

echo -e "\n📋 LOGS (10 dernières lignes):"
docker-compose logs --tail=10 elastic-thehive-sync

echo -e "\n🔍 TEST RAPIDE:"
echo "   TheHive: http://localhost:9000"
echo "   Kibana:  http://localhost:5601"
echo -e "\n✅ Déploiement terminé"
