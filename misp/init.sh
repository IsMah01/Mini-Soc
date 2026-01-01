#!/bin/bash
set -e

echo "[MISP] Waiting for database..."
sleep 30

echo "[MISP] Setting up persistent configuration..."
CONFIG_FILE="/var/www/MISP/app/Config/config.php"

# Ensure config exists
if [ ! -f "$CONFIG_FILE" ]; then
    cp /var/www/MISP/app/Config/config.default.php "$CONFIG_FILE"
fi

# Apply configuration fixes
echo "[MISP] Applying configuration..."
sed -i "s|'baseurl' => 'https://localhost'|'baseurl' => 'https://localhost:8443'|g" "$CONFIG_FILE"
sed -i "s|'external_baseurl' => 'https://localhost'|'external_baseurl' => 'https://localhost:8443'|g" "$CONFIG_FILE"
sed -i "s|'rest_client_baseurl' => 'https://localhost'|'rest_client_baseurl' => 'https://localhost:8443'|g" "$CONFIG_FILE"

# Fix Redis configuration
sed -i "s|tcp://redis:6379|tcp://misp-redis:6379|g" /etc/php/8.2/fpm/php.ini

echo "[MISP] Configuration completed"