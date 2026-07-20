# Microsoft Sentinel Architecture Reference

## Platform Architecture

### Log Analytics Workspace

Sentinel runs on top of Azure Log Analytics (part of Azure Monitor). The workspace is the fundamental data store.

**Data flow:**
```
Data Sources
    |
    ├── Azure services (Activity, Diagnostics)
    ├── Microsoft 365 / Defender XDR
    ├── CEF/Syslog (via Azure Monitor Agent)
    ├── Custom logs (Log Analytics API / DCR)
    ├── AWS / GCP (cloud connectors)
    └── Third-party (Codeless Connector Platform / REST API)
    |
    v
Data Collection Rules (DCR) -- filter, transform, route
    |
    v
Log Analytics Workspace
    |
    ├── Analytics logs (full KQL, 90-day free retention)
    ├── Basic logs (limited KQL, 30-day retention, lower cost)
    └── Archive tier (search jobs only, up to 12 years)
    |
    v
Sentinel Analytics Engine
    |
    ├── Scheduled analytics rules
    ├── NRT rules
    ├── Fusion ML engine
    ├── Anomaly detection
    ├── Threat intelligence matching
    └── UEBA behavioral models
    |
    v
Incidents + Entities + Investigations
    |
    v
Automation Rules + Playbooks (Logic Apps)
```

### Data Collection Rules (DCR)

DCRs control how data enters the workspace:

- **Transformation** -- KQL-based filtering and transformation before ingestion
- **Routing** -- Send data to different tables or workspaces
- **Filtering** -- Drop events that don't provide security value
- **Enrichment** -- Add calculated fields during ingestion

**DCR pipeline:**
```
Data Source --> Azure Monitor Agent / API --> DCR Transform --> Workspace Table
```

**Example: Filter Windows Security events**
```json
{
  "properties": {
    "dataFlows": [
      {
        "streams": ["Microsoft-SecurityEvent"],
        "transformKql": "source | where EventID in (4624, 4625, 4648, 4672, 4688, 4720, 4726, 4728, 4732, 4756)",
        "destinations": ["la-workspace"],
        "outputStream": "Microsoft-SecurityEvent"
      }
    ]
  }
}
```

### Data Connectors Deep Dive

**Connector types:**

| Type | Mechanism | Examples |
|---|---|---|
| **Service-to-service** | Azure API integration | Microsoft 365, Defender XDR, Entra ID |
| **Azure Monitor Agent (AMA)** | Agent on Windows/Linux | Syslog, CEF, Windows Events, custom logs |
| **REST API** | Pull via API | AWS CloudTrail, Okta, custom sources |
| **Codeless Connector Platform (CCP)** | Configuration-driven REST | Partner connectors without code |
| **Azure Functions** | Serverless polling | Custom API integrations |
| **Syslog / CEF** | Network-based | Firewalls, network appliances |

**CEF/Syslog architecture:**
```
Network Device --> Syslog/CEF --> Linux VM (AMA + DCR) --> Workspace

For scale: Network Device --> Syslog --> rsyslog/syslog-ng (load balancer) --> Linux VMs (AMA)
```

### ASIM Architecture

ASIM (Advanced Security Information Model) normalizes data at query time using KQL functions:

```
Raw Table (vendor-specific)
    |
    v
Source-specific Parser (vimAuthenticationAADSigninLogs)
    - Maps vendor fields to ASIM schema
    - Applies source-specific logic
    |
    v
Unifying Parser (imAuthentication)
    - Unions all source-specific parsers
    - Returns normalized results
    |
    v
Analytics Rule / Hunting Query
    - Queries unified parser
    - Works across all data sources
```

**ASIM schemas and key fields:**

| Schema | Table Function | Key Normalized Fields |
|---|---|---|
| Authentication | `imAuthentication` | EventResult, TargetUsername, SrcIpAddr, LogonMethod |
| DNS | `imDns` | DnsQuery, DnsResponseCode, SrcIpAddr, DnsQueryType |
| Network Session | `imNetworkSession` | SrcIpAddr, DstIpAddr, DstPortNumber, NetworkProtocol |
| Process Event | `imProcessEvent` | ActingProcessName, TargetProcessName, TargetUsername |
| File Event | `imFileEvent` | TargetFileName, ActorUsername, SrcIpAddr |
| Web Session | `imWebSession` | Url, HttpStatusCode, SrcIpAddr, DstIpAddr |

**Creating a custom ASIM parser:**
```kql
// Example: source-specific parser for a custom auth log
let vimAuthenticationCustomApp = (
    disabled:bool = false
) {
    CustomApp_CL
    | where not(disabled)
    | project-rename
        TargetUsername = Username_s,
        SrcIpAddr = SourceIP_s
    | extend
        EventResult = iff(Status_s == "Success", "Success", "Failure"),
        EventType = "Logon",
        EventProduct = "CustomApp",
        EventVendor = "Internal",
        EventSchema = "Authentication",
        EventSchemaVersion = "0.1.3"
};
```

### Fusion ML Engine

Fusion is Sentinel's ML-based multi-stage attack detection:

- **Pre-trained models** -- Detects multi-stage attack scenarios (e.g., suspicious sign-in followed by data exfiltration)
- **Cross-source correlation** -- Correlates signals from Microsoft Defender XDR, Entra ID, firewalls, and other sources
- **Automatic** -- No configuration needed. Enabled by default.
- **Kill chain mapping** -- Maps detected stages to cyber kill chain phases

**Example Fusion scenario:**
```
Stage 1: Anomalous sign-in (Entra ID) from suspicious IP
    +
Stage 2: Suspicious inbox rule creation (Office 365)
    +
Stage 3: Mass email forwarding to external address (Office 365)
    =
Fusion Incident: Business Email Compromise detected
```

### Multi-Workspace Patterns

**Pattern 1: Single workspace (recommended for most)**
```
All data --> Workspace A --> Sentinel
Benefits: Simplest management, full cross-correlation
```

**Pattern 2: Multi-workspace, single tenant**
```
EU data --> Workspace-EU --> Sentinel
US data --> Workspace-US --> Sentinel
Cross-workspace queries for correlation
Benefits: Data residency compliance
```

**Pattern 3: Multi-tenant (MSSP)**
```
Customer A data --> Customer A workspace --> Sentinel (via Azure Lighthouse)
Customer B data --> Customer B workspace --> Sentinel (via Azure Lighthouse)
MSSP central workspace --> Aggregated alerts
Benefits: Tenant isolation, MSSP central management
```

**Cross-workspace query:**
```kql
union
    workspace("workspace-eu").SecurityEvent,
    workspace("workspace-us").SecurityEvent
| where EventID == 4625
| summarize FailureCount = count() by TargetAccount, bin(TimeGenerated, 1h)
```

### Unified Defender Portal

Sentinel is migrating to the unified Defender portal (security.microsoft.com):

- **Single pane of glass** -- Sentinel incidents, Defender XDR incidents, and advanced hunting in one portal
- **Unified incident queue** -- All security incidents from all Microsoft security products
- **Cross-product hunting** -- KQL across Sentinel tables and Defender XDR tables
- **Migration timeline** -- Mandatory by July 2026
- **New features** -- Some new Sentinel features are only available in the unified portal

## Capacity and Limits

| Resource | Limit |
|---|---|
| **Tables per workspace** | 10,000 |
| **Columns per table** | 500 |
| **Analytics rules per workspace** | 512 (scheduled + NRT) |
| **Automation rules** | 512 |
| **Incidents open** | 50,000 |
| **Bookmarks** | 50,000 |
| **Watchlists** | 100 watchlists, 10M rows total |
| **Query timeout (analytics rule)** | 10 minutes |
| **Query result limit** | 10,000 rows (for analytics rules) |
| **NRT rule execution** | Every ~1 minute, 30-second query timeout |
| **DCR transformations** | 10 DCRs per data flow, KQL subset only |

## High Availability and Disaster Recovery

- **Built-in** -- Log Analytics is zone-redundant within a region
- **Cross-region** -- No native cross-region replication. Use dual-ingest (send data to two workspaces in different regions) for DR.
- **Backup** -- Export analytics rules, automation rules, and playbooks via ARM templates or Sentinel Repositories (Git integration)
- **Infrastructure as Code** -- Use Terraform, Bicep, or ARM templates for workspace and Sentinel configuration
- **Sentinel Repositories** -- Native Git integration for analytics rules, hunting queries, and playbooks (CI/CD)
