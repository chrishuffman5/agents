# Rapid7 InsightVM Architecture Reference

## Console Architecture

### Deployment Model

InsightVM is an on-premises application (or Rapid7-hosted "InsightVM Cloud") with the following components:

```
InsightVM Console (Management Server)
+-------------------------------------+
| Apache Tomcat (Web UI + API)        |
| Port: 3780 (HTTPS)                  |
|                                     |
| NSC (Nexpose Security Console)      |
| Core scanning orchestration         |
|                                     |
| PostgreSQL (embedded)               |
| Asset inventory, vuln DB, reports   |
|                                     |
| Scan Engine (local, built-in)       |
| Scans local network segment         |
+------------------+------------------+
                   |
    +--------------+--------------+
    |                             |
+---+---+                   +----+---+
| Remote|                   | Remote |
| Scan  |                   | Scan   |
| Engine|                   | Engine |
| Site A|                   | Site B |
+-------+                   +--------+
```

### Console Hardware Requirements

| Scale | vCPU | RAM | Disk |
|---|---|---|---|
| Small (< 2,500 assets) | 8 | 16GB | 500GB |
| Medium (2,500-25,000) | 8-16 | 32GB | 1TB |
| Large (25,000-100,000) | 16 | 64GB | 2TB+ |
| Very Large (100,000+) | 32 | 128GB | 4TB+ |

**Note:** InsightVM uses PostgreSQL for all data storage. Disk I/O is the primary performance bottleneck. Use SSD storage for console database volume.

**Console ports:**
- 3780/TCP: Web UI and API (HTTPS)
- 40814/TCP: Scan engine communication (console <--> remote engines)

### Console Storage Paths

```
$RAPID7_HOME (default: /opt/rapid7/nexpose on Linux)
├── logs/           # Console and scan engine logs
│   ├── nsc.log     # Main console log
│   └── nse.log     # Scan engine log (if co-located)
├── backup/         # Automated backup files
├── nxdata/         # Scan results, vuln data
│   ├── scans/      # Individual scan result files
│   └── reports/    # Generated report files
└── conf/           # Configuration files
    ├── nsc.xml     # Console configuration
    └── userdb.xml  # User database (if not LDAP)
```

## Distributed Scan Engine Architecture

### Scan Engine Components

Remote scan engines extend scanning coverage to network segments the console cannot directly reach.

**Engine communication model:**
- Console initiates connection TO engine on port 40814 (engines poll console)
- OR: Engine initiates connection TO console (recommended for NAT/firewall traversal)
- All communication over TLS-encrypted channel
- Scan jobs pushed from console, results returned to console

**Engine hardware requirements:**

| Scale | vCPU | RAM | Disk |
|---|---|---|---|
| Standard | 4 | 8GB | 100GB |
| High-throughput | 8 | 16GB | 200GB |

### Engine Placement Strategy

```
Corporate Network (10.0.0.0/8)
    |
    +-- Datacenter A (10.1.0.0/16)  <-- Scan Engine DC-A
    |
    +-- Datacenter B (10.2.0.0/16)  <-- Scan Engine DC-B
    |
    +-- AWS VPC (172.31.0.0/16)     <-- Scan Engine AWS (EC2)
    |
    +-- Remote Office (192.168.1.0/24) <-- Scan Engine Office-1
    |
    +-- DMZ (10.99.0.0/24)          <-- Scan Engine DMZ (for external-facing)
    |
InsightVM Console (communicates with all engines)
```

**Rules for engine placement:**
1. One engine per major network segment (reduces cross-firewall scan traffic)
2. Engine must have network access to all scan targets in its segment
3. Engine must have TCP 40814 to console (or console has 40814 to engine -- depends on direction)
4. For cloud: Deploy engine as EC2/Azure VM, use private IP, configure site with cloud CIDR

### Distributed Scan Architecture in InsightVM

**Scan Pool:**
- Group multiple engines for load balancing
- InsightVM distributes scan targets across engines in pool
- Engine failure is handled by redistributing to remaining engines

**Scan scope binding:**
- Site → Scan Engine (or Pool) binding
- Site A (DC-A assets) → Engine DC-A
- Site B (Cloud assets) → Engine AWS

## Insight Agent Architecture

### Agent Components

```
Endpoint
+-------------------------------------+
| Rapid7 Insight Agent                |
|                                     |
| ir_agent (core service)             |
|   - Orchestrator                    |
|   - Update manager                  |
|                                     |
| insight_agent (assessment engine)   |
|   - Vulnerability detection         |
|   - Software inventory              |
|   - EDR telemetry (if InsightIDR)   |
|                                     |
| Local data store                    |
+------------------------------+------+
                               |
                               | HTTPS/443 (outbound only)
                               |
+------------------------------+------+
| Rapid7 Insight Platform (Cloud)     |
| cloud.insight.rapid7.com            |
| - Agent management                  |
| - Assessment processing             |
| - EDR/SIEM data ingestion           |
+-------------------------------------+
                |
+---------------+
| InsightVM Console
| (receives processed vuln data)
+---------------+
```

**Agent scan cycle:**
1. Agent checks in to Insight Platform
2. Platform sends assessment manifest (what to scan for)
3. Agent runs local vulnerability checks
4. Results uploaded to Insight Platform
5. Platform processes results, sends to InsightVM Console
6. Console incorporates into asset vulnerability inventory

**Agent scan frequency:**
- Full assessment: Every 6 hours by default
- Policy changes apply immediately on next check-in
- On-demand scan: Request immediate assessment from console

### Agent Token Management

Agents use tokens for authentication to the Insight Platform.

**Token flow:**
1. Generate agent token in InsightVM console (Agents > Generate Token)
2. Token embedded in agent installer package
3. Agent registers with Insight Platform using token
4. Platform assigns unique agent ID to each endpoint
5. Token used for all subsequent communications

**Token rotation:**
- Tokens don't expire once registered
- Rotate tokens annually or on security incidents
- Old token deactivated in console; new agent installers use new token

## Active Risk Score Computation

### Score Factors and Weights

Active Risk Score is computed per asset as an aggregate of per-vulnerability risk scores.

**Per-vulnerability risk factors:**

| Factor | Data Source | Impact |
|---|---|---|
| CVSS Base Score | NVD | Foundation (0-10 normalized to 0-1000) |
| Exploit Code Maturity | Metasploit, ExploitDB, Rapid7 Intel | +Significant if Metasploit module exists |
| Exploit Published | Rapid7 Threat Intelligence | Moderate increase if PoC published |
| Malware Association | Rapid7 Threat Intelligence | Large increase if active malware campaign |
| EPSS Score | FIRST | Proportional to exploitation probability |
| KEV Status | CISA | High weight (confirmed exploitation) |

**Asset criticality multiplier:**
- Very High: ×1.5
- High: ×1.25
- Medium: ×1.0
- Low: ×0.75
- Very Low: ×0.5

**Asset Risk Score formula (simplified):**
```
Asset_Risk = Σ(vulnerability_risk_score × asset_criticality_multiplier)
             capped at 1000
```

### Risk Score Update Frequency

- **CVSS:** Updates when NVD updates the CVE (infrequent)
- **EPSS:** Updates daily (Rapid7 pulls daily EPSS scores from FIRST)
- **Exploit/Malware data:** Updates as Rapid7 Threat Intel detects new activity (daily-weekly)
- **KEV:** Updates when CISA adds new entries (multiple times per week)
- **Asset risk recalculation:** Recalculated when any input changes, or on scheduled scan

## InsightConnect Integration Architecture

InsightConnect is Rapid7's SOAR platform that automates workflows across security tools.

### InsightConnect Connectivity

```
InsightVM Console/API
        |
        | REST API (HTTP triggers, data exchange)
        |
InsightConnect Orchestration Platform
        |
        +-- Jira Connector
        +-- ServiceNow Connector
        +-- Slack Connector
        +-- Email Connector
        +-- PagerDuty Connector
        +-- Custom Script Steps (Python, PowerShell)
```

### Common InsightVM + InsightConnect Workflows

**Workflow 1: Critical Vuln Alert + Ticket**
```
Trigger: InsightVM detects new Critical vulnerability on production asset
Step 1: Get asset owner from tag or CMDB lookup
Step 2: Create ServiceNow incident with vuln details
Step 3: Send Slack DM to asset owner with details and deadline
Step 4: [7 days later] Check if ticket resolved -- if not, escalate to manager
```

**Workflow 2: KEV Immediate Response**
```
Trigger: CISA KEV catalog updated with new entry
Step 1: Query InsightVM for assets with new KEV CVE
Step 2: If affected assets found:
  - Create high-priority tickets in ServiceNow for each affected asset
  - Send PagerDuty alert to on-call security engineer
  - Notify asset owners via email
Step 3: Schedule automatic rescan after 48 hours to verify patch
```

**Workflow 3: Post-Patch Verification**
```
Trigger: ITSM ticket status changes to "Patched/Closed"
Step 1: Trigger targeted rescan of asset (InsightVM API: POST /scans)
Step 2: Wait for scan completion (poll scan status)
Step 3: Check if vulnerability still present after rescan
  - If gone: Mark ticket as verified, update InsightVM status
  - If still present: Reopen ticket with note "Rescan shows vuln still present"
```

### InsightVM API for Automation

**Scan orchestration:**
```python
import requests
import time

BASE_URL = "https://insightvm.company.com:3780/api/3"
AUTH = ("apiuser", "apipassword")

def trigger_targeted_scan(site_id, asset_ids):
    """Trigger a targeted scan of specific assets."""
    scan_config = {
        "assetIds": asset_ids,
        "name": f"Targeted Rescan - {int(time.time())}",
        "templateId": "exhaustive"
    }
    response = requests.post(
        f"{BASE_URL}/sites/{site_id}/scans",
        auth=AUTH,
        json=scan_config,
        verify=True
    )
    return response.json()["id"]

def wait_for_scan(scan_id, max_wait=3600):
    """Poll until scan completes."""
    deadline = time.time() + max_wait
    while time.time() < deadline:
        response = requests.get(
            f"{BASE_URL}/scans/{scan_id}",
            auth=AUTH,
            verify=True
        )
        status = response.json()["status"]
        if status in ["finished", "stopped", "error"]:
            return status
        time.sleep(60)
    return "timeout"

def get_asset_vulnerabilities(asset_id, severity="critical"):
    """Get vulnerabilities for a specific asset."""
    response = requests.get(
        f"{BASE_URL}/assets/{asset_id}/vulnerabilities",
        auth=AUTH,
        params={"severity": severity},
        verify=True
    )
    return response.json()["resources"]
```

## Backup and High Availability

### Console Backup

**Automated backup configuration:**
- Console creates daily backup to `$RAPID7_HOME/backup/`
- Configure backup retention: Administration > Maintenance
- Backup includes: asset data, scan history, configuration, user accounts
- Does NOT include: raw scan engine results (these are processed into the database)

**Backup restore procedure:**
1. Stop InsightVM service
2. Copy backup file to console
3. Run: `nsc -r /path/to/backup.zip`
4. Start InsightVM service

### High Availability Options

InsightVM does not have native HA. Options:

**Option 1: VM-level HA**
- Run console on VMware with vSphere HA or Hyper-V Failover Clustering
- VM restarts automatically on host failure
- RTO: ~5-10 minutes

**Option 2: Cold standby**
- Backup console + restore to standby hardware on failure
- RTO: ~30-60 minutes

**Option 3: Scan engine redundancy**
- Multiple scan engines per segment ensure scanning continues if one fails
- Console failure = reporting/UI down, but engines can buffer results
