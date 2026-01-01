# Configuring Cortex in TheHive

## Steps:

1. **Get Cortex API Key:**
   - Check: `cat cortex/config/application.conf | grep -i key`
   - Or check Cortex logs: `docker logs cortex | grep -i key`
   - Common location: Look for `secret` or `key` in the config file

2. **Add Cortex in TheHive:**
   - Open TheHive: http://localhost:9000
   - Login: admin / admin123
   - Go to: Admin > Cortex > Cortex servers
   - Click: "New Cortex server"
   - Fill in:
     - Name: LocalCortex
     - URL: http://cortex:9001
     - Authentication type: Bearer
     - Token: [Cortex API Key from step 1]
   - Click "Save"

3. **Enable Analyzers:**
   - Go to: Admin > Cortex > Analyzers
   - Enable analyzers you want (VirusTotal, AbuseIPDB, etc.)
   - Configure API keys for each analyzer if needed

4. **Test Analysis:**
   - Create or open a case in TheHive
   - Add an observable (IP, domain, hash, etc.)
   - Click "Actions" > "Run analyzers"
   - Select Cortex server and analyzers
   - Run analysis

## Common Cortex Analyzers to Enable:
- AbuseIPDB_1_0
- VirusTotal_3_0 (requires VT API key)
- URLhaus_1_0
- FileInfo_4_0
- Hashdd_1_0
- IPInfo_1_0

## Getting API Keys for Analyzers:
- VirusTotal: https://www.virustotal.com/gui/join-us
- AbuseIPDB: https://www.abuseipdb.com/
- Hybrid Analysis: https://www.hybrid-analysis.com/
