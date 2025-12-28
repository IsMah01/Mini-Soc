#!/bin/bash

# =============================================================================
# TheHive Integration Test Script - VERSION CORRIGÉE
# Tests: TheHive API, Cassandra, MinIO (S3), Elasticsearch
# =============================================================================

# Remove set -e to prevent script from stopping on first error
# set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
THEHIVE_URL="http://localhost:9000"
ELASTICSEARCH_URL="http://localhost:9200"
MINIO_URL="http://localhost:9002"
CASSANDRA_HOST="localhost"
CASSANDRA_PORT="9042"

# TheHive credentials - MODIFIEZ SI NÉCESSAIRE
THEHIVE_USER="test@thehive.local"
THEHIVE_PASSWORD="test"

# Elasticsearch credentials
ES_USER="elastic"
ES_PASSWORD="changeme123"

# MinIO credentials
MINIO_USER="admin"
MINIO_PASSWORD="changeme123"

# Timeout for curl commands (in seconds)
CURL_TIMEOUT=10

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
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
# TheHive API Tests
# =============================================================================

test_thehive_status() {
    print_header "Testing TheHive API Status"
    
    print_test "Checking TheHive public status..."
    
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -w "HTTP_CODE:%{http_code}" "$THEHIVE_URL/api/v1/status/public" 2>&1)
    
    if echo "$RESPONSE" | grep -q "HTTP_CODE:"; then
        HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
        BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')
        
        if [ "$HTTP_CODE" = "200" ]; then
            print_pass "TheHive is responding (HTTP $HTTP_CODE)"
            echo "  Response: $BODY"
        else
            print_fail "TheHive returned HTTP $HTTP_CODE"
        fi
    else
        print_fail "Cannot connect to TheHive (timeout or connection refused)"
        echo "  Error: $RESPONSE"
    fi
}

test_thehive_login() {
    print_header "Testing TheHive Authentication"
    
    print_test "Attempting login..."
    
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -w "HTTP_CODE:%{http_code}" \
        -X POST "$THEHIVE_URL/api/v1/login" \
        -H "Content-Type: application/json" \
        -d "{\"user\": \"$THEHIVE_USER\", \"password\": \"$THEHIVE_PASSWORD\"}" \
        -c /tmp/thehive_cookies.txt 2>&1)
    
    if echo "$RESPONSE" | grep -q "HTTP_CODE:"; then
        HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
        BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')
        
        if [ "$HTTP_CODE" = "200" ]; then
            print_pass "Login successful (HTTP $HTTP_CODE)"
            if echo "$BODY" | grep -q "login"; then
                LOGIN_NAME=$(echo "$BODY" | grep -o '"login":"[^"]*"' | head -1)
                print_info "User authenticated: $LOGIN_NAME"
            fi
        else
            print_fail "Login failed (HTTP $HTTP_CODE)"
            echo "  Response: $BODY"
        fi
    else
        print_fail "Cannot connect to TheHive for login"
    fi
}

test_thehive_session() {
    print_header "Testing TheHive Session Persistence"
    
    print_test "Checking session with cookies..."
    
    if [ ! -f /tmp/thehive_cookies.txt ]; then
        print_warn "No cookie file found, skipping session test"
        return
    fi
    
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -w "HTTP_CODE:%{http_code}" \
        "$THEHIVE_URL/api/v1/user/current" \
        -b /tmp/thehive_cookies.txt 2>&1)
    
    if echo "$RESPONSE" | grep -q "HTTP_CODE:"; then
        HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
        BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')
        
        if [ "$HTTP_CODE" = "200" ]; then
            print_pass "Session is valid (HTTP $HTTP_CODE)"
            if echo "$BODY" | grep -q "login"; then
                print_info "Current user: $(echo "$BODY" | grep -o '"login":"[^"]*"')"
            fi
        else
            print_fail "Session invalid (HTTP $HTTP_CODE)"
        fi
    else
        print_fail "Cannot verify session"
    fi
}

test_thehive_create_case() {
    print_header "Testing TheHive Case Creation"
    
    if [ ! -f /tmp/thehive_cookies.txt ]; then
        print_warn "No session, skipping case creation"
        return
    fi
    
    CASE_TITLE="Test Case - $(date +%s)"
    TIMESTAMP=$(($(date +%s) * 1000))
    
    print_test "Creating a test case..."
    
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -w "HTTP_CODE:%{http_code}" \
        -X POST "$THEHIVE_URL/api/v1/case" \
        -H "Content-Type: application/json" \
        -b /tmp/thehive_cookies.txt \
        -d "{
            \"title\": \"$CASE_TITLE\",
            \"description\": \"Automated test case for integration testing\",
            \"severity\": 2,
            \"startDate\": $TIMESTAMP,
            \"flag\": false,
            \"tlp\": 2,
            \"pap\": 2,
            \"tags\": [\"test\", \"automated\"]
        }" 2>&1)
    
    if echo "$RESPONSE" | grep -q "HTTP_CODE:"; then
        HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
        BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')
        
        if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
            print_pass "Case created successfully (HTTP $HTTP_CODE)"
            CASE_ID=$(echo "$BODY" | grep -o '"_id":"[^"]*"' | head -1 | cut -d'"' -f4)
            if [ -n "$CASE_ID" ]; then
                print_info "Case ID: $CASE_ID"
                echo "$CASE_ID" > /tmp/test_case_id.txt
            fi
        else
            print_fail "Case creation failed (HTTP $HTTP_CODE)"
            echo "  Response: $BODY"
        fi
    else
        print_fail "Cannot create case"
    fi
}

test_thehive_add_observable() {
    print_header "Testing TheHive Observable Creation"
    
    if [ ! -f /tmp/test_case_id.txt ]; then
        print_warn "No test case ID found, skipping observable test"
        return
    fi
    
    CASE_ID=$(cat /tmp/test_case_id.txt)
    
    print_test "Adding IP observable to case..."
    
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -w "HTTP_CODE:%{http_code}" \
        -X POST "$THEHIVE_URL/api/v1/case/$CASE_ID/observable" \
        -H "Content-Type: application/json" \
        -b /tmp/thehive_cookies.txt \
        -d "{
            \"dataType\": \"ip\",
            \"data\": \"192.168.1.100\",
            \"message\": \"Test suspicious IP address\",
            \"tlp\": 2,
            \"ioc\": true,
            \"sighted\": true,
            \"tags\": [\"test\", \"suspicious\"]
        }" 2>&1)
    
    if echo "$RESPONSE" | grep -q "HTTP_CODE:"; then
        HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
        
        if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
            print_pass "Observable added successfully (HTTP $HTTP_CODE)"
        else
            print_fail "Observable creation failed (HTTP $HTTP_CODE)"
        fi
    else
        print_fail "Cannot add observable"
    fi
}

test_thehive_list_cases() {
    print_header "Testing TheHive Case Listing"
    
    if [ ! -f /tmp/thehive_cookies.txt ]; then
        print_warn "No session, skipping case listing"
        return
    fi
    
    print_test "Listing all cases..."
    
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -w "HTTP_CODE:%{http_code}" \
        -X POST "$THEHIVE_URL/api/v1/query" \
        -H "Content-Type: application/json" \
        -b /tmp/thehive_cookies.txt \
        -d '{"query": [{"_name": "listCase"}]}' 2>&1)
    
    if echo "$RESPONSE" | grep -q "HTTP_CODE:"; then
        HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
        BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')
        
        if [ "$HTTP_CODE" = "200" ]; then
            CASE_COUNT=$(echo "$BODY" | grep -o '"_id"' | wc -l)
            print_pass "Case listing successful (HTTP $HTTP_CODE)"
            print_info "Total cases found: $CASE_COUNT"
        else
            print_fail "Case listing failed (HTTP $HTTP_CODE)"
        fi
    else
        print_fail "Cannot list cases"
    fi
}

# =============================================================================
# Cassandra Tests
# =============================================================================

test_cassandra_connection() {
    print_header "Testing Cassandra Connection"
    
    print_test "Checking Cassandra connectivity..."
    
    # Check if container is running
    if ! docker ps | grep -q cassandra; then
        print_fail "Cassandra container is not running"
        return
    fi
    
    # Test keyspace existence
    RESULT=$(docker exec cassandra cqlsh -e "DESCRIBE KEYSPACES;" 2>&1)
    
    if echo "$RESULT" | grep -q "thehive"; then
        print_pass "Cassandra is running and TheHive keyspace exists"
        
        print_test "Checking TheHive tables in Cassandra..."
        TABLE_COUNT=$(docker exec cassandra cqlsh -e "USE thehive; DESCRIBE TABLES;" 2>&1 | wc -l)
        
        if [ "$TABLE_COUNT" -gt 2 ]; then
            print_pass "TheHive tables are present in Cassandra"
            print_info "Number of table lines: $TABLE_COUNT"
        else
            print_warn "Few or no TheHive tables found"
        fi
    else
        print_fail "Cassandra not accessible or TheHive keyspace missing"
        echo "  Result: $RESULT"
    fi
}

# =============================================================================
# Elasticsearch Tests
# =============================================================================

test_elasticsearch_connection() {
    print_header "Testing Elasticsearch Connection"
    
    print_test "Checking Elasticsearch cluster health..."
    
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -u "$ES_USER:$ES_PASSWORD" \
        "$ELASTICSEARCH_URL/_cluster/health" 2>&1)
    
    if echo "$RESPONSE" | grep -q '"status"'; then
        STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        NODES=$(echo "$RESPONSE" | grep -o '"number_of_nodes":[0-9]*' | cut -d':' -f2)
        
        if [ "$STATUS" = "green" ] || [ "$STATUS" = "yellow" ]; then
            print_pass "Elasticsearch cluster is healthy (Status: $STATUS)"
            print_info "Number of nodes: $NODES"
        else
            print_fail "Elasticsearch cluster status: $STATUS"
        fi
    else
        print_fail "Cannot connect to Elasticsearch"
        echo "  Response: $RESPONSE"
    fi
}

test_elasticsearch_thehive_index() {
    print_header "Testing Elasticsearch TheHive Index"
    
    print_test "Checking for TheHive indices..."
    
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -u "$ES_USER:$ES_PASSWORD" \
        "$ELASTICSEARCH_URL/_cat/indices?v" 2>&1)
    
    if echo "$RESPONSE" | grep -q "thehive"; then
        print_pass "TheHive indices found in Elasticsearch"
        INDEX_INFO=$(echo "$RESPONSE" | grep "thehive" | head -3)
        print_info "Indices:"
        echo "$INDEX_INFO" | while read -r line; do
            echo "    $line"
        done
    else
        print_warn "No TheHive indices found (may be created on first data)"
    fi
    
    print_test "Checking TheHive index documents..."
    
    DOC_RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -u "$ES_USER:$ES_PASSWORD" \
        "$ELASTICSEARCH_URL/thehive*/_count" 2>&1)
    
    if echo "$DOC_RESPONSE" | grep -q '"count"'; then
        DOC_COUNT=$(echo "$DOC_RESPONSE" | grep -o '"count":[0-9]*' | cut -d':' -f2)
        if [ -n "$DOC_COUNT" ] && [ "$DOC_COUNT" -gt 0 ]; then
            print_pass "TheHive has $DOC_COUNT documents indexed"
        else
            print_info "No documents indexed yet (normal for fresh install)"
        fi
    else
        print_info "Could not count documents"
    fi
}

# =============================================================================
# MinIO (S3) Tests
# =============================================================================

test_minio_connection() {
    print_header "Testing MinIO (S3 Storage) Connection"
    
    print_test "Checking MinIO health..."
    
    RESPONSE=$(curl -s --max-time $CURL_TIMEOUT -w "HTTP_CODE:%{http_code}" \
        "$MINIO_URL/minio/health/live" 2>&1)
    
    if echo "$RESPONSE" | grep -q "HTTP_CODE:"; then
        HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
        
        if [ "$HTTP_CODE" = "200" ]; then
            print_pass "MinIO is healthy (HTTP $HTTP_CODE)"
        else
            print_fail "MinIO health check failed (HTTP $HTTP_CODE)"
        fi
    else
        print_fail "Cannot connect to MinIO"
    fi
}

test_minio_bucket() {
    print_header "Testing MinIO TheHive Bucket"
    
    print_test "Checking if 'thehive' bucket exists..."
    
    # Check if container is running
    if ! docker ps | grep -q minio; then
        print_fail "MinIO container is not running"
        return
    fi
    
    # Check bucket with mc
    BUCKET_LIST=$(docker exec minio mc ls minio/ 2>&1)
    
    if echo "$BUCKET_LIST" | grep -q "thehive"; then
        print_pass "TheHive bucket exists in MinIO"
        
        print_test "Checking bucket contents..."
        FILE_COUNT=$(docker exec minio mc ls minio/thehive/ 2>&1 | wc -l)
        print_info "Files/objects in bucket: $FILE_COUNT"
    else
        print_fail "TheHive bucket does not exist"
        print_info "Create it with:"
        echo "  docker exec minio mc alias set minio http://localhost:9000 admin changeme123"
        echo "  docker exec minio mc mb minio/thehive"
    fi
}

# =============================================================================
# Cleanup
# =============================================================================

cleanup() {
    print_header "Cleanup"
    
    print_info "Cleaning up test artifacts..."
    rm -f /tmp/thehive_cookies.txt 2>/dev/null
    rm -f /tmp/test_case_id.txt 2>/dev/null
    
    print_info "Test cases created remain in TheHive (delete manually if needed)"
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
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  ALL TESTS PASSED! TheHive is ready!  ${NC}"
        echo -e "${GREEN}========================================${NC}"
    elif [ $PASS_RATE -gt 80 ]; then
        echo ""
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${YELLOW}  Most tests passed. Minor issues.     ${NC}"
        echo -e "${YELLOW}========================================${NC}"
    else
        echo ""
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}  Multiple failures. Check the logs.   ${NC}"
        echo -e "${RED}========================================${NC}"
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║           TheHive Integration Test Suite                  ║"
    echo "║     Testing: TheHive, Cassandra, Elasticsearch, MinIO    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo "Starting tests... (timeout per request: ${CURL_TIMEOUT}s)"
    echo ""
    
    # TheHive API Tests
    test_thehive_status
    test_thehive_login
    test_thehive_session
    test_thehive_create_case
    test_thehive_add_observable
    test_thehive_list_cases
    
    # Cassandra Tests
    test_cassandra_connection
    
    # Elasticsearch Tests
    test_elasticsearch_connection
    test_elasticsearch_thehive_index
    
    # MinIO Tests
    test_minio_connection
    test_minio_bucket
    
    # Cleanup
    cleanup
    
    # Summary
    print_summary
}

# Run main function
main "$@"