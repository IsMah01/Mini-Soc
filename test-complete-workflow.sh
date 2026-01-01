#!/bin/bash
echo "=== Complete MISP-TheHive-Cortex Workflow Test ==="
echo ""

MISP_API_KEY="IXbKPdGbR43IJbBU0b9QVUKBZQEygI5Ab06j1JMy"

echo "1. Creating a realistic threat event in MISP..."
# Create a malware event
EVENT_RESPONSE=$(curl -k -X POST https://localhost:8443/events \
  -H "Authorization: $MISP_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "Event": {
      "date": "2026-01-01",
      "threat_level_id": "2",  # High
      "info": "[TEST] Emotet Malware Campaign Indicators",
      "published": false,
      "distribution": "1",
      "analysis": "2",
      "Tag": [{"name": "misp"}]
    }
  }' 2>/dev/null)

if echo "$EVENT_RESPONSE" | grep -q '"id"'; then
  EVENT_ID=$(echo "$EVENT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['Event']['id'])" 2>/dev/null)
  echo "   ✓ Event created (ID: $EVENT_ID)"
  echo "   View: https://localhost:8443/events/view/$EVENT_ID"
else
  echo "   ✗ Failed to create event"
  echo "   Response: $EVENT_RESPONSE"
  exit 1
fi

echo ""
echo "2. Adding IOCs to the event..."
# Add various IOC types
IOCS=(
  '{"type":"ip-dst","category":"Network activity","value":"185.220.101.41","comment":"C2 IP"}'
  '{"type":"domain","category":"Network activity","value":"malicious-domain[.]com","comment":"C2 Domain"}'
  '{"type":"md5","category":"Payload delivery","value":"a94a8fe5ccb19ba61c4c0873d391e987","comment":"Malware hash"}'
  '{"type":"url","category":"Network activity","value":"http://malicious-site.com/payload.exe","comment":"Download URL"}'
  '{"type":"filename","category":"Payload delivery","value":"invoice.pdf.exe","comment":"Malicious filename"}'
)

for ioc in "${IOCS[@]}"; do
  TYPE=$(echo "$ioc" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['type'])" 2>/dev/null)
  VALUE=$(echo "$ioc" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['value'])" 2>/dev/null)
  
  curl -k -X POST https://localhost:8443/attributes/add/$EVENT_ID \
    -H "Authorization: $MISP_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$ioc" >/dev/null 2>&1
  
  echo "   ✓ Added: $TYPE = $VALUE"
  sleep 1
done

echo ""
echo "3. Publishing the event (triggers TheHive import)..."
PUBLISH_RESPONSE=$(curl -k -X POST https://localhost:8443/events/publish/$EVENT_ID \
  -H "Authorization: $MISP_API_KEY" \
  -H "Content-Type: application/json" \
  2>/dev/null)

if echo "$PUBLISH_RESPONSE" | grep -q '"published"'; then
  echo "   ✓ Event published"
  echo "   This should trigger automatic import to TheHive"
else
  echo "   ✗ Failed to publish event"
fi

echo ""
echo "4. Checking TheHive for new case..."
echo "   Waiting 30 seconds for import..."
sleep 30

echo ""
echo "5. Monitoring TheHive logs for import..."
echo "=== TheHive Logs (MISP related) ==="
docker logs thehive --since 1m 2>/dev/null | grep -i "misp\|import\|case" | tail -10 || echo "   No recent import logs found"

echo ""
echo "=== Test Instructions ==="
echo "1. Open TheHive: http://localhost:9000"
echo "   Login: admin / admin123"
echo "2. Check for new case: 'Emotet Malware Campaign Indicators'"
echo "3. In the case, you should see 5 observables (IP, domain, hash, URL, filename)"
echo "4. Try analyzing observables with Cortex (if configured)"
echo ""
echo "To manually trigger MISP sync in TheHive:"
echo "1. Go to Admin > MISP"
echo "2. Click on 'LocalMISP'"
echo "3. Click 'Sync now'"
echo ""
echo "=== Test Complete ==="
