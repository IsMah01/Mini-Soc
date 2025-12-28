#!/bin/bash

# ============================================================================
# CORTEX DIAGNOSTIC SCRIPT - Complete Analysis
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  CORTEX DIAGNOSTIC SCRIPT${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================================
# 1. CONTAINER STATUS
# ============================================================================
echo -e "${GREEN}[1] Checking Container Status...${NC}"
docker compose ps cortex
echo ""

# ============================================================================
# 2. DOCKER IMAGE INFO
# ============================================================================
echo -e "${GREEN}[2] Docker Image Information...${NC}"
docker inspect cortex | grep -A 5 "Image"
docker exec cortex cat /etc/os-release 2>/dev/null || echo "Cannot read OS info"
echo ""

# ============================================================================
# 3. PYTHON VERSION & AVAILABILITY
# ============================================================================
echo -e "${GREEN}[3] Python Environment...${NC}"
echo "Python versions available:"
docker exec cortex which python 2>/dev/null && docker exec cortex python --version || echo "  python: NOT FOUND"
docker exec cortex which python2 2>/dev/null && docker exec cortex python2 --version || echo "  python2: NOT FOUND"
docker exec cortex which python3 2>/dev/null && docker exec cortex python3 --version || echo "  python3: NOT FOUND"
echo ""

# ============================================================================
# 4. PACKAGE MANAGERS
# ============================================================================
echo -e "${GREEN}[4] Package Managers Available...${NC}"
docker exec cortex which pip 2>/dev/null && echo "  pip: FOUND" || echo "  pip: NOT FOUND"
docker exec cortex which pip3 2>/dev/null && echo "  pip3: FOUND" || echo "  pip3: NOT FOUND"
docker exec cortex which apt-get 2>/dev/null && echo "  apt-get: FOUND" || echo "  apt-get: NOT FOUND"
docker exec cortex which yum 2>/dev/null && echo "  yum: FOUND" || echo "  yum: NOT FOUND"
echo ""

# ============================================================================
# 5. CORTEXUTILS STATUS
# ============================================================================
echo -e "${GREEN}[5] CortexUtils Status...${NC}"
docker exec cortex python3 -c "import cortexutils; print('cortexutils version:', cortexutils.__version__)" 2>/dev/null || echo "  cortexutils: NOT INSTALLED"
echo ""

# ============================================================================
# 6. ANALYZERS DIRECTORY
# ============================================================================
echo -e "${GREEN}[6] Analyzers Directory Structure...${NC}"
echo "Checking /opt/Cortex-Analyzers/analyzers:"
docker exec cortex ls -la /opt/Cortex-Analyzers/analyzers 2>/dev/null | head -10 || echo "  Directory NOT FOUND"
echo ""
echo "Checking /opt/cortex/analyzers:"
docker exec cortex ls -la /opt/cortex/analyzers 2>/dev/null | head -10 || echo "  Directory NOT FOUND"
echo ""

# ============================================================================
# 7. CORTEX CONFIGURATION
# ============================================================================
echo -e "${GREEN}[7] Cortex Configuration (analyzer paths)...${NC}"
docker exec cortex cat /etc/cortex/application.conf | grep -A 10 "analyzer" || echo "  Cannot read config"
echo ""

# ============================================================================
# 8. JOB DIRECTORY
# ============================================================================
echo -e "${GREEN}[8] Job Directory Status...${NC}"
docker exec cortex ls -la /tmp/cortex-jobs 2>/dev/null || echo "  Job directory NOT FOUND"
echo ""

# ============================================================================
# 9. ELASTICSEARCH CONNECTION
# ============================================================================
echo -e "${GREEN}[9] Elasticsearch Connection...${NC}"
docker exec cortex curl -s -u elastic:changeme123 http://elasticsearch:9200/_cluster/health 2>/dev/null | grep -o '"status":"[^"]*"' || echo "  Cannot connect to Elasticsearch"
echo ""

# ============================================================================
# 10. CORTEX LOGS (Last 50 lines)
# ============================================================================
echo -e "${GREEN}[10] Recent Cortex Logs...${NC}"
docker compose logs cortex --tail=50 | grep -E "(ERROR|WARN|cortexutils|analyzer)" || echo "  No relevant logs found"
echo ""

# ============================================================================
# 11. NETWORK CONNECTIVITY
# ============================================================================
echo -e "${GREEN}[11] Network Connectivity...${NC}"
echo "Can Cortex reach Elasticsearch?"
docker exec cortex ping -c 2 elasticsearch 2>/dev/null && echo "  YES" || echo "  NO"
echo ""

# ============================================================================
# 12. VOLUMES & MOUNTS
# ============================================================================
echo -e "${GREEN}[12] Docker Volumes & Mounts...${NC}"
docker inspect cortex | grep -A 20 "Mounts"
echo ""

# ============================================================================
# 13. TEST ANALYZER EXECUTION
# ============================================================================
echo -e "${GREEN}[13] Test Analyzer Execution...${NC}"
echo "Attempting to run a simple analyzer..."
docker exec cortex ls /opt/Cortex-Analyzers/analyzers/Abuse_Finder 2>/dev/null && echo "  Abuse_Finder directory exists" || echo "  Abuse_Finder NOT FOUND"
echo ""

# ============================================================================
# 14. DOCKER SOCKET ACCESS
# ============================================================================
echo -e "${GREEN}[14] Docker Socket Access...${NC}"
docker exec cortex ls -la /var/run/docker.sock 2>/dev/null || echo "  Docker socket NOT accessible"
echo ""

# ============================================================================
# 15. SYSTEM RESOURCES
# ============================================================================
echo -e "${GREEN}[15] Container Resources...${NC}"
docker stats cortex --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo ""

# ============================================================================
# 16. DEBIAN REPOSITORIES STATUS
# ============================================================================
echo -e "${GREEN}[16] Debian Repositories Status...${NC}"
docker exec cortex cat /etc/apt/sources.list 2>/dev/null || echo "  Cannot read sources.list"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  DIAGNOSTIC COMPLETE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Key Issues to Check:${NC}"
echo "1. Is Python 3.7 available?"
echo "2. Is cortexutils installed?"
echo "3. Are analyzers mounted correctly?"
echo "4. Is the job directory accessible?"
echo "5. Can Cortex connect to Elasticsearch?"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "Review the output above and identify the root cause."
echo ""