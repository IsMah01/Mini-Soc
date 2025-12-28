#!/bin/bash
API_KEY="9zc1U2guwWpqI4gTi+iXRHPaN3aPsV+0"
CORTEX_URL="http://localhost:9001"

echo "=== Testing Cortex Analyzers ==="

# Function to run analyzer
run_analyzer() {
    local analyzer=$1
    local data=$2
    local data_type=$3
    
    echo -e "\n🔍 Testing: $analyzer"
    echo "   Input: $data ($data_type)"
    
    response=$(curl -XPOST -s \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"data\":\"$data\",\"dataType\":\"$data_type\"}" \
        "$CORTEX_URL/api/analyzer/$analyzer/run")
    
    # Extract key information
    status=$(echo $response | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status', 'N/A'))" 2>/dev/null || echo "ERROR")
    echo "   Status: $status"
    
    # Show summary if available
    summary=$(echo $response | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    report = d.get('report', {})
    if 'summary' in report:
        print('   Summary:', report['summary'])
    elif 'taxonomies' in report:
        tax = report['taxonomies']
        if tax:
            print('   Result:', tax[0].get('value', 'N/A'))
except:
    pass
" 2>/dev/null)
    
    [ ! -z "$summary" ] && echo "$summary"
}

# Run tests
run_analyzer "MaxMind_GeoIP_3_0" "8.8.8.8" "ip"
run_analyzer "GoogleDNS_resolve" "github.com" "domain"
run_analyzer "UnshortenLink" "https://tinyurl.com/4w7m9nkz" "url"
run_analyzer "FireHOLBlocklists" "5.188.206.10" "ip"
run_analyzer "GoogleDNS_resolve" "microsoft.com" "domain"
run_analyzer "MaxMind_GeoIP_3_0" "1.1.1.1" "ip"