#!/bin/bash

# =============================================================================
# Mini-SOC Migration Script - ES 8.x to ES 7.x
# Tests all components after migration
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ELASTIC_PASSWORD="changeme123"
THEHIVE_USER="test@thehive.local"
THEHIVE_PASSWORD="secret"
CURL_TIMEOUT=15

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# =============================================================================
# Pre-Migration Checks
# =============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    print_test "Docker is installed..."
    if command -v docker &> /dev/null; then
        print_pass "Docker found: $(docker --version)"
    else
        print_fail "Docker not found"
        exit 1
    fi
    
    print_test "Docker Compose is installed..."
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        print_pass "Docker Compose found"
    else
        print_fail "Docker Compose not found"
        exit 1
    fi
    
    print_test "docker-compose.yml exists..."
    if [ -f "docker-compose.yml" ]; then
        print_pass "docker-compose.yml found"
    else
        print_fail "docker-compose.yml not found in current directory"
        exit 1
    fi
    
    print_test ".env file exists..."
    if [ -f ".env" ]; then
        print_pass ".env file found"
        
        # Check ES version
        ES_VERSION=$(grep "ELASTIC_VERSION=" .env | cut -d'=' -f2)
        print_info "Configured Elasticsearch version: $ES_VERSION"
    else
        print_fail ".env file not found"
        exit 1
    fi
}

# =============================================================================
# Elasticsearch Tests
# =============================================================================

test_elasticsearch() {
    print_header "Testing Elasticsearch"
    
    print_test "Elasticsearch is running..."
    if docker ps | grep -q elasticsearch; then
        print_pass "Elasticsearch container is running"
    else
        print_fail "Elasticsearch container is not running"
        return 1
    fi
    
    print_test "Elasticsearch API responds..."
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -u elastic:$ELASTIC_PASSWORD http://localhost:9200 2>&1)
    
    if echo "$RESPONSE" | grep -q '"version"'; then
        ES_VERSION=$(echo "$RESPONSE" | grep -o '"number" : "[^"]*"' | cut -d'"' -f4)
        print_pass "Elasticsearch is responding (Version: $ES_VERSION)"
        
        # Check if it's ES 7.x
        if echo "$ES_VERSION" | grep -q "^7\."; then
            print_info "✓ Elasticsearch 7.x detected - Compatible with Cortex 3.1.7"
        elif echo "$ES_VERSION" | grep -q "^8\."; then
            print_warn "⚠ Elasticsearch 8.x detected - NOT compatible with Cortex 3.1.7"
        fi
    else
        print_fail "Elasticsearch not responding"
        echo "  Response: $RESPONSE"
        return 1
    fi
    
    print_test "Cluster health..."
    HEALTH=$(curl -s --max-time $CURL_TIMEOUT -u elastic:$ELASTIC_PASSWORD http://localhost:9200/_cluster/health 2>&1)
    
    if echo "$HEALTH" | grep -q '"status"'; then
        STATUS=$(echo "$HEALTH" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        if [ "$STATUS" = "green" ] || [ "$STATUS" = "yellow" ]; then
            print_pass "Cluster health: $STATUS"
        else
            print_fail "Cluster health: $STATUS"
        fi
    else
        print_fail "Cannot check cluster health"
    fi
}

# =============================================================================
# Create ES Users
# =============================================================================

create_elasticsearch_users() {
    print_header "Creating Elasticsearch Users"
    
    print_step "Creating thehive_user..."
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -X POST "http://localhost:9200/_security/user/thehive_user" \
        -u elastic:$ELASTIC_PASSWORD \
        -H "Content-Type: application/json" \
        -d '{
            "password": "changeme123",
            "roles": ["superuser"],
            "full_name": "TheHive Service Account"
        }' 2>&1)
    
    if echo "$RESPONSE" | grep -q '"created":true' || echo "$RESPONSE" | grep -q "already exists"; then
        print_pass "thehive_user created/exists"
    else
        print_warn "Could not create thehive_user: $RESPONSE"
    fi
    
    print_step "Setting kibana_system password..."
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -X POST "http://localhost:9200/_security/user/kibana_system/_password" \
        -u elastic:$ELASTIC_PASSWORD \
        -H "Content-Type: application/json" \
        -d '{"password": "changeme123"}' 2>&1)
    
    if echo "$RESPONSE" | grep -q '{}' || echo "$RESPONSE" | grep -q "password"; then
        print_pass "kibana_system password set"
    else
        print_warn "Could not set kibana_system password: $RESPONSE"
    fi
}

# =============================================================================
# Cortex Tests
# =============================================================================

test_cortex() {
    print_header "Testing Cortex"
    
    print_test "Cortex container is running..."
    if docker ps | grep -q cortex; then
        print_pass "Cortex container is running"
    else
        print_fail "Cortex container is not running"
        return 1
    fi
    
    print_test "Cortex API responds..."
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT http://localhost:9001/api/status 2>&1)
    
    if echo "$RESPONSE" | grep -q '"Cortex"'; then
        CORTEX_VERSION=$(echo "$RESPONSE" | grep -o '"Cortex":"[^"]*"' | cut -d'"' -f4)
        print_pass "Cortex is responding (Version: $CORTEX_VERSION)"
    else
        print_fail "Cortex not responding"
        return 1
    fi
    
    print_test "Testing database migration..."
    MIGRATE_RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -X POST http://localhost:9001/api/maintenance/migrate 2>&1)
    
    if echo "$MIGRATE_RESPONSE" | grep -q '"type":"InternalError"'; then
        if echo "$MIGRATE_RESPONSE" | grep -q "include_type_name"; then
            print_fail "Cortex migration FAILED - ES 8.x incompatibility detected"
            print_warn "You need Elasticsearch 7.x for Cortex 3.1.7"
        else
            print_fail "Cortex migration error: $(echo "$MIGRATE_RESPONSE" | head -c 200)"
        fi
    elif echo "$MIGRATE_RESPONSE" | grep -q '"message"'; then
        print_pass "Cortex migration successful"
    else
        print_warn "Cortex migration response unclear: $(echo "$MIGRATE_RESPONSE" | head -c 100)"
    fi
    
    print_test "Checking Cortex index in Elasticsearch..."
    INDEX_EXISTS=$(curl -s --max-time $CURL_TIMEOUT -u elastic:$ELASTIC_PASSWORD \
        "http://localhost:9200/_cat/indices" | grep -c "cortex" 2>/dev/null || echo "0")
    
    if [ "$INDEX_EXISTS" -gt 0 ]; then
        print_pass "Cortex index exists in Elasticsearch"
    else
        print_warn "Cortex index not found (will be created after migration)"
    fi
}

# =============================================================================
# TheHive Tests
# =============================================================================

test_thehive() {
    print_header "Testing TheHive"
    
    print_test "TheHive container is running..."
    if docker ps | grep -q thehive; then
        print_pass "TheHive container is running"
    else
        print_fail "TheHive container is not running"
        return 1
    fi
    
    print_test "TheHive API responds..."
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT http://localhost:9000/api/v1/status/public 2>&1)
    
    if echo "$RESPONSE" | grep -q '"version"'; then
        VERSION=$(echo "$RESPONSE" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        print_pass "TheHive is responding (Version: $VERSION)"
    else
        print_fail "TheHive not responding"
        return 1
    fi
    
    print_test "TheHive Elasticsearch connection..."
    # Check if TheHive has indexed data
    DOC_COUNT=$(curl -s --max-time $CURL_TIMEOUT -u elastic:$ELASTIC_PASSWORD \
        "http://localhost:9200/thehive*/_count" 2>&1 | grep -o '"count":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$DOC_COUNT" ] && [ "$DOC_COUNT" -gt 0 ]; then
        print_pass "TheHive has $DOC_COUNT documents in Elasticsearch"
    else
        print_info "No TheHive documents yet (normal for fresh install)"
    fi
}

# =============================================================================
# Cassandra Tests
# =============================================================================

test_cassandra() {
    print_header "Testing Cassandra"
    
    print_test "Cassandra container is running..."
    if docker ps | grep -q cassandra; then
        print_pass "Cassandra container is running"
    else
        print_fail "Cassandra container is not running"
        return 1
    fi
    
    print_test "TheHive keyspace exists..."
    KEYSPACES=$(docker exec cassandra cqlsh -e "DESCRIBE KEYSPACES;" 2>&1)
    
    if echo "$KEYSPACES" | grep -q "thehive"; then
        print_pass "TheHive keyspace exists in Cassandra"
    else
        print_warn "TheHive keyspace not found (will be created when TheHive starts)"
    fi
}

# =============================================================================
# MinIO Tests
# =============================================================================

test_minio() {
    print_header "Testing MinIO"
    
    print_test "MinIO container is running..."
    if docker ps | grep -q minio; then
        print_pass "MinIO container is running"
    else
        print_fail "MinIO container is not running"
        return 1
    fi
    
    print_test "MinIO health check..."
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -w "HTTP_CODE:%{http_code}" \
        "http://localhost:9002/minio/health/live" 2>&1)
    
    if echo "$RESPONSE" | grep -q "HTTP_CODE:200"; then
        print_pass "MinIO is healthy"
    else
        print_fail "MinIO health check failed"
    fi
    
    print_test "TheHive bucket exists..."
    BUCKET_EXISTS=$(docker exec minio mc ls minio/ 2>&1 | grep -c "thehive" || echo "0")
    
    if [ "$BUCKET_EXISTS" -gt 0 ]; then
        print_pass "TheHive bucket exists"
    else
        print_warn "TheHive bucket not found"
        print_info "Create it with: docker exec minio mc mb minio/thehive"
    fi
}

# =============================================================================
# Kibana Tests
# =============================================================================

test_kibana() {
    print_header "Testing Kibana"
    
    print_test "Kibana container is running..."
    if docker ps | grep -q kibana; then
        print_pass "Kibana container is running"
    else
        print_fail "Kibana container is not running"
        return 1
    fi
    
    print_test "Kibana API responds..."
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT "http://localhost:5601/api/status" 2>&1)
    
    if echo "$RESPONSE" | grep -q '"overall"'; then
        print_pass "Kibana is responding"
    else
        print_warn "Kibana may still be starting up..."
    fi
}

# =============================================================================
# Full Integration Test
# =============================================================================

test_full_integration() {
    print_header "Full Integration Test"
    
    print_test "All core services are running..."
    SERVICES_UP=0
    SERVICES_NEEDED=5
    
    for service in elasticsearch cassandra minio thehive cortex; do
        if docker ps | grep -q $service; then
            SERVICES_UP=$((SERVICES_UP + 1))
        fi
    done
    
    if [ $SERVICES_UP -eq $SERVICES_NEEDED ]; then
        print_pass "All $SERVICES_NEEDED core services are running"
    else
        print_fail "Only $SERVICES_UP/$SERVICES_NEEDED services running"
    fi
    
    print_test "Network connectivity between services..."
    # Test if TheHive can reach Elasticsearch
    ES_REACHABLE=$(docker exec thehive wget -qO- --timeout=5 http://elasticsearch:9200 2>&1 | grep -c "cluster_name" || echo "0")
    
    if [ "$ES_REACHABLE" -gt 0 ]; then
        print_pass "TheHive can reach Elasticsearch"
    else
        print_warn "Cannot verify TheHive->ES connectivity"
    fi
}

# =============================================================================
# Summary
# =============================================================================

print_summary() {
    print_header "TEST SUMMARY"
    
    echo ""
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    PASS_RATE=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi
    
    echo "Pass Rate: $PASS_RATE%"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo ""
        echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ALL TESTS PASSED! Ready for Cortex! ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    elif [ $PASS_RATE -gt 70 ]; then
        echo ""
        echo -e "${YELLOW}╔═══════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  Most tests passed. Minor issues.    ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════╝${NC}"
    else
        echo ""
        echo -e "${RED}╔═══════════════════════════════════════╗${NC}"
        echo -e "${RED}║  Multiple failures. Check configs.   ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════╝${NC}"
    fi
}

# =============================================================================
# Main Menu
# =============================================================================

show_menu() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║        Mini-SOC Migration & Test Script                   ║"
    echo "║        ES 8.x → ES 7.x Migration Helper                   ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo "Select an option:"
    echo "1) Run all tests (no migration)"
    echo "2) Create Elasticsearch users only"
    echo "3) Test Cortex specifically"
    echo "4) Check ES/Cortex compatibility"
    echo "5) Full diagnostic report"
    echo "q) Quit"
    echo ""
    read -p "Choice: " choice
    
    case $choice in
        1)
            check_prerequisites
            test_elasticsearch
            test_cassandra
            test_minio
            test_thehive
            test_cortex
            test_kibana
            test_full_integration
            print_summary
            ;;
        2)
            check_prerequisites
            test_elasticsearch
            create_elasticsearch_users
            ;;
        3)
            test_elasticsearch
            test_cortex
            ;;
        4)
            print_header "ES/Cortex Compatibility Check"
            RESPONSE=$(curl -s --max-time 10 -u elastic:$ELASTIC_PASSWORD http://localhost:9200 2>&1)
            ES_VERSION=$(echo "$RESPONSE" | grep -o '"number" : "[^"]*"' | cut -d'"' -f4)
            
            echo "Elasticsearch Version: $ES_VERSION"
            
            if echo "$ES_VERSION" | grep -q "^7\."; then
                echo -e "${GREEN}✓ COMPATIBLE with Cortex 3.1.7${NC}"
            elif echo "$ES_VERSION" | grep -q "^8\."; then
                echo -e "${RED}✗ NOT COMPATIBLE with Cortex 3.1.7${NC}"
                echo "  Cortex 3.1.7 requires Elasticsearch 7.x"
                echo "  Please migrate to ES 7.17.18"
            else
                echo -e "${YELLOW}? Unknown version${NC}"
            fi
            ;;
        5)
            check_prerequisites
            test_elasticsearch
            create_elasticsearch_users
            test_cassandra
            test_minio
            test_thehive
            test_cortex
            test_kibana
            test_full_integration
            print_summary
            ;;
        q|Q)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# =============================================================================
# Entry Point
# =============================================================================

if [ "$1" = "--auto" ]; then
    # Automatic mode - run all tests
    check_prerequisites
    test_elasticsearch
    test_cassandra
    test_minio
    test_thehive
    test_cortex
    test_kibana
    test_full_integration
    print_summary
else
    # Interactive mode
    show_menu
fi