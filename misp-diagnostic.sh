#!/bin/bash
#
# Script de Diagnostic Complet MISP
# Vérifie tous les composants et identifie les problèmes
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    DIAGNOSTIC COMPLET MISP - Mini-SOC Lab${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Fonction d'affichage
print_ok() { echo -e "  ${GREEN}✓${NC} $1"; }
print_fail() { echo -e "  ${RED}✗${NC} $1"; }
print_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
print_info() { echo -e "  ${BLUE}ℹ${NC} $1"; }

ISSUES=0

# ===========================================
# 1. CONTENEURS
# ===========================================
echo -e "${YELLOW}1. ÉTAT DES CONTENEURS${NC}"
echo "-------------------------------------------"
for container in misp-core misp-db misp-redis misp-modules; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        status=$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null || echo "no-healthcheck")
        if [ "$status" = "healthy" ] || [ "$status" = "no-healthcheck" ]; then
            print_ok "$container: Running"
        else
            print_warn "$container: Running but $status"
        fi
    else
        print_fail "$container: NOT RUNNING"
        ((ISSUES++))
    fi
done
echo ""

# ===========================================
# 2. CONNECTIVITÉ RÉSEAU
# ===========================================
echo -e "${YELLOW}2. CONNECTIVITÉ RÉSEAU${NC}"
echo "-------------------------------------------"

# Test DNS misp-redis
dns_test=$(docker exec misp-core getent hosts misp-redis 2>/dev/null | wc -l)
if [ "$dns_test" -gt 0 ]; then
    ip=$(docker exec misp-core getent hosts misp-redis 2>/dev/null | awk '{print $1}')
    print_ok "DNS misp-redis résolu: $ip"
else
    print_fail "DNS misp-redis NON résolu"
    ((ISSUES++))
fi

# Test DNS misp-db
dns_test=$(docker exec misp-core getent hosts misp-db 2>/dev/null | wc -l)
if [ "$dns_test" -gt 0 ]; then
    print_ok "DNS misp-db résolu"
else
    print_fail "DNS misp-db NON résolu"
    ((ISSUES++))
fi

# Test si 'redis' est résolu (ne devrait PAS l'être maintenant)
dns_redis=$(docker exec misp-core getent hosts redis 2>/dev/null | wc -l)
if [ "$dns_redis" -gt 0 ]; then
    print_warn "DNS 'redis' résolu (potentiel conflit)"
else
    print_ok "DNS 'redis' non résolu (correct - évite conflit)"
fi
echo ""

# ===========================================
# 3. CONNEXION REDIS
# ===========================================
echo -e "${YELLOW}3. CONNEXION REDIS${NC}"
echo "-------------------------------------------"

# Test connexion TCP à misp-redis
redis_connect=$(docker exec misp-core bash -c "timeout 5 bash -c 'echo > /dev/tcp/misp-redis/6379' 2>/dev/null && echo 'OK'" 2>/dev/null)
if [ "$redis_connect" = "OK" ]; then
    print_ok "Connexion TCP à misp-redis:6379"
else
    print_fail "Impossible de se connecter à misp-redis:6379"
    ((ISSUES++))
fi

# Test authentification Redis (via PHP)
redis_auth=$(docker exec misp-core php -r "
\$redis = new Redis();
try {
    \$redis->connect('misp-redis', 6379, 5);
    \$redis->auth('redispassword');
    echo \$redis->ping() ? 'PONG' : 'FAIL';
} catch (Exception \$e) {
    echo 'ERROR: ' . \$e->getMessage();
}
" 2>/dev/null)

if [ "$redis_auth" = "PONG" ] || [ "$redis_auth" = "1" ]; then
    print_ok "Authentification Redis OK"
else
    print_fail "Authentification Redis ÉCHEC: $redis_auth"
    ((ISSUES++))
fi
echo ""

# ===========================================
# 4. CONNEXION BASE DE DONNÉES
# ===========================================
echo -e "${YELLOW}4. CONNEXION BASE DE DONNÉES${NC}"
echo "-------------------------------------------"

db_test=$(docker exec misp-db mysql -u misp -pmisp123 misp -e "SELECT 1;" 2>/dev/null | grep -c "1")
if [ "$db_test" -gt 0 ]; then
    print_ok "Connexion MySQL OK"
else
    print_fail "Connexion MySQL ÉCHEC"
    ((ISSUES++))
fi

table_count=$(docker exec misp-db mysql -u misp -pmisp123 misp -e "SHOW TABLES;" 2>/dev/null | wc -l)
if [ "$table_count" -gt 50 ]; then
    print_ok "Base de données initialisée ($((table_count-1)) tables)"
else
    print_fail "Base de données incomplète ($((table_count-1)) tables)"
    ((ISSUES++))
fi

user_count=$(docker exec misp-db mysql -u misp -pmisp123 misp -e "SELECT COUNT(*) FROM users;" 2>/dev/null | tail -1)
print_info "Nombre d'utilisateurs: $user_count"
echo ""

# ===========================================
# 5. CONFIGURATION PHP
# ===========================================
echo -e "${YELLOW}5. CONFIGURATION PHP${NC}"
echo "-------------------------------------------"

session_handler=$(docker exec misp-core grep "^session.save_handler" /etc/php/8.2/fpm/php.ini 2>/dev/null | head -1)
print_info "Session handler: $session_handler"

session_path=$(docker exec misp-core grep "^session.save_path" /etc/php/8.2/fpm/php.ini 2>/dev/null | head -1)
print_info "Session path: $session_path"

if echo "$session_path" | grep -q "redis:6379"; then
    print_fail "Sessions configurées pour 'redis' (devrait être 'misp-redis' ou 'files')"
    ((ISSUES++))
elif echo "$session_path" | grep -q "misp-redis"; then
    print_ok "Sessions configurées pour misp-redis"
elif echo "$session_path" | grep -q "/tmp"; then
    print_ok "Sessions configurées en fichiers (/tmp)"
fi
echo ""

# ===========================================
# 6. CONFIGURATION MISP
# ===========================================
echo -e "${YELLOW}6. CONFIGURATION MISP${NC}"
echo "-------------------------------------------"

# Baseurl
baseurl=$(docker exec misp-core /var/www/MISP/app/Console/cake Admin getSetting MISP.baseurl 2>/dev/null | grep '"value"' | sed 's/.*"value": "\(.*\)".*/\1/')
print_info "MISP.baseurl: $baseurl"
if echo "$baseurl" | grep -q ":8443"; then
    print_ok "Port 8443 inclus dans baseurl"
else
    print_fail "Port 8443 MANQUANT dans baseurl"
    ((ISSUES++))
fi

# Redis host
redis_host=$(docker exec misp-core /var/www/MISP/app/Console/cake Admin getSetting MISP.redis_host 2>/dev/null | grep '"value"' | sed 's/.*"value": "\(.*\)".*/\1/')
print_info "MISP.redis_host: $redis_host"
if [ "$redis_host" = "misp-redis" ]; then
    print_ok "Redis host correctement configuré"
else
    print_fail "Redis host incorrect (devrait être 'misp-redis')"
    ((ISSUES++))
fi

# External baseurl
ext_baseurl=$(docker exec misp-core /var/www/MISP/app/Console/cake Admin getSetting MISP.external_baseurl 2>/dev/null | grep '"value"' | sed 's/.*"value": "\(.*\)".*/\1/')
print_info "MISP.external_baseurl: $ext_baseurl"
echo ""

# ===========================================
# 7. PERMISSIONS FICHIERS
# ===========================================
echo -e "${YELLOW}7. PERMISSIONS FICHIERS${NC}"
echo "-------------------------------------------"

config_perms=$(docker exec misp-core ls -la /var/www/MISP/app/Config/config.php 2>/dev/null | awk '{print $1, $3, $4}')
print_info "config.php: $config_perms"
if echo "$config_perms" | grep -q "www-data"; then
    print_ok "Propriétaire config.php correct"
else
    print_fail "Propriétaire config.php incorrect"
    ((ISSUES++))
fi

tmp_writable=$(docker exec misp-core bash -c "[ -w /var/www/MISP/app/tmp ] && echo 'OK'" 2>/dev/null)
if [ "$tmp_writable" = "OK" ]; then
    print_ok "Dossier tmp accessible en écriture"
else
    print_fail "Dossier tmp NON accessible en écriture"
    ((ISSUES++))
fi
echo ""

# ===========================================
# 8. WORKERS
# ===========================================
echo -e "${YELLOW}8. WORKERS MISP${NC}"
echo "-------------------------------------------"

worker_status=$(docker exec misp-core supervisorctl status 2>/dev/null)
running=$(echo "$worker_status" | grep -c "RUNNING")
fatal=$(echo "$worker_status" | grep -c "FATAL")

print_info "Workers en cours: $running"
if [ "$fatal" -gt 0 ]; then
    print_warn "Workers en erreur: $fatal"
fi

for worker_type in default email cache prio update scheduler; do
    count=$(echo "$worker_status" | grep "${worker_type}_" | grep -c "RUNNING")
    total=$(echo "$worker_status" | grep -c "${worker_type}_")
    if [ "$total" -gt 0 ]; then
        if [ "$count" -eq "$total" ]; then
            print_ok "$worker_type: $count/$total"
        else
            print_warn "$worker_type: $count/$total"
        fi
    fi
done
echo ""

# ===========================================
# 9. INTERFACE WEB
# ===========================================
echo -e "${YELLOW}9. INTERFACE WEB${NC}"
echo "-------------------------------------------"

http_code=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8443/users/login 2>/dev/null)
print_info "Code HTTP: $http_code"

if [ "$http_code" = "200" ]; then
    print_ok "Page de login accessible (HTTP 200)"
elif [ "$http_code" = "302" ]; then
    print_warn "Redirection détectée (HTTP 302) - problème de session probable"
    ((ISSUES++))
else
    print_fail "Page non accessible (HTTP $http_code)"
    ((ISSUES++))
fi

# Vérifier si les CSS sont chargés
css_test=$(curl -k -s https://localhost:8443/css/main.css 2>/dev/null | head -1)
if [ -n "$css_test" ]; then
    print_ok "Fichiers CSS accessibles"
else
    print_fail "Fichiers CSS NON accessibles"
    ((ISSUES++))
fi
echo ""

# ===========================================
# 10. LOGS D'ERREURS
# ===========================================
echo -e "${YELLOW}10. ERREURS RÉCENTES${NC}"
echo "-------------------------------------------"

nginx_errors=$(docker exec misp-core tail -20 /var/log/nginx/error.log 2>/dev/null | grep -c "error")
if [ "$nginx_errors" -eq 0 ]; then
    print_ok "Pas d'erreurs nginx récentes"
else
    print_warn "$nginx_errors erreurs nginx récentes"
    print_info "Voir: docker exec misp-core tail -20 /var/log/nginx/error.log"
fi

misp_errors=$(docker exec misp-core tail -50 /var/www/MISP/app/tmp/logs/error.log 2>/dev/null | grep -c "Error\|Exception")
if [ "$misp_errors" -eq 0 ]; then
    print_ok "Pas d'erreurs MISP récentes"
else
    print_warn "$misp_errors erreurs MISP récentes"
    print_info "Voir: docker exec misp-core tail -20 /var/www/MISP/app/tmp/logs/error.log"
fi
echo ""

# ===========================================
# RÉSUMÉ
# ===========================================
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}                  RÉSUMÉ${NC}"
echo -e "${BLUE}================================================${NC}"

if [ "$ISSUES" -eq 0 ]; then
    echo -e "${GREEN}✓ Tous les tests passés ! MISP devrait fonctionner.${NC}"
else
    echo -e "${RED}✗ $ISSUES problème(s) détecté(s)${NC}"
fi
echo ""

# ===========================================
# RECOMMANDATIONS
# ===========================================
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}              CORRECTIONS SUGGÉRÉES${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if echo "$session_path" | grep -q "redis:6379"; then
    echo -e "${RED}CRITIQUE: Sessions PHP pointent vers 'redis' inexistant${NC}"
    echo "Exécutez:"
    echo '  docker exec -u root misp-core sed -i "s/redis:6379/misp-redis:6379/g" /etc/php/8.2/fpm/php.ini'
    echo '  docker compose restart misp-core'
    echo ""
fi

if [ "$redis_host" != "misp-redis" ]; then
    echo -e "${YELLOW}Redis host incorrect dans MISP${NC}"
    echo "Exécutez:"
    echo '  docker exec misp-core /var/www/MISP/app/Console/cake Admin setSetting MISP.redis_host misp-redis'
    echo ""
fi

if ! echo "$baseurl" | grep -q ":8443"; then
    echo -e "${YELLOW}Baseurl sans port 8443${NC}"
    echo "Exécutez:"
    echo '  docker exec misp-core /var/www/MISP/app/Console/cake Admin setSetting MISP.baseurl "https://localhost:8443"'
    echo ""
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}           COMMANDES DE RÉPARATION${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "# Corriger les sessions PHP pour utiliser misp-redis:"
echo 'docker exec -u root misp-core sed -i "s/redis:6379/misp-redis:6379/g" /etc/php/8.2/fpm/php.ini'
echo ""
echo "# Ou utiliser les sessions fichier (plus simple):"
echo 'docker exec -u root misp-core sed -i "s/session.save_handler = redis/session.save_handler = files/g" /etc/php/8.2/fpm/php.ini'
echo 'docker exec -u root misp-core sed -i "s|session.save_path = .*|session.save_path = /tmp|g" /etc/php/8.2/fpm/php.ini'
echo ""
echo "# Redémarrer après modifications:"
echo "docker compose restart misp-core"
echo ""
echo "# Effacer le cache navigateur et cookies, puis accéder à:"
echo "https://localhost:8443/users/login"
echo ""