# Qualys Architecture Reference

## Qualys Cloud Platform Architecture

### Platform Overview

Qualys is a multi-tenant SaaS platform. All vulnerability data, scan configurations, and asset inventory reside in Qualys's cloud infrastructure. Customer deployments consist of:

1. **Cloud Platform (SaaS):** All processing, storage, and UI hosted by Qualys
2. **Cloud Agents:** Lightweight agents on endpoints that report to the platform
3. **Scanner Appliances:** On-premises scanners for network-based scanning
4. **API Connectors:** Cloud provider API connections (AWS, Azure, GCP) for TotalCloud

```
Qualys Cloud Platform (Multi-tenant SaaS)
+-------------------------------------------+
|  Web UI    |  REST API  |  Plugin Updates  |
|            |            |                  |
|  VMDR      |  TotalCloud|  WAS   |  PC     |
|            |            |                  |
|  TruRisk Engine  |  Asset Inventory DB     |
+-------------------------------------------+
          ^                    ^
          |                    |
 Cloud Agents (HTTPS)   Scanner Appliances (HTTPS)
 (endpoints)            (on-premises networks)
          ^
          |
 Cloud API Connectors
 (AWS/Azure/GCP APIs)
```

### Qualys Data Centers / Platforms

Qualys operates separate platform instances (PODs) by region and compliance boundary:

| Platform | Region | URL |
|---|---|---|
| US Platform 1 | US | qualysapi.qualys.com |
| US Platform 2 | US | qualysapi.qg2.apps.qualys.com |
| US Platform 3 | US | qualysapi.qg3.apps.qualys.com |
| EU Platform 1 | EU | qualysapi.eu.qualys.com |
| APAC Platform 1 | APAC | qualysapi.qg1.apps.qualys.in |
| UK Platform | UK | qualysapi.qg1.apps.qualys.co.uk |
| Canada Platform | CA | qualysapi.qg1.apps.qualys.ca |
| UAE Platform | UAE | qualysapi.qg1.apps.qualys.ae |

**Note:** Your account is assigned to a specific platform at subscription creation. All API calls and agent configurations must use your platform's hostname.

## Qualys Cloud Agent Architecture

### Agent Components

```
Endpoint
+----------------------------------+
| Qualys Cloud Agent               |
|                                  |
| qualys-cloud-agent process       |
|   - Assessment engine            |
|   - Inventory collection         |
|   - Policy compliance engine     |
|   - FIM engine (if enabled)      |
|   - Configuration store          |
|   - Local cache                  |
+------------------+---------------+
                   |
                   | HTTPS/443 (outbound)
                   | Direct or proxy
                   |
+------------------+---------------+
| Qualys Cloud Platform            |
| - Assessment processing          |
| - Plugin/manifest distribution   |
| - Command/control                |
+----------------------------------+
```

**Agent footprint:**
- Binary size: ~50MB
- Memory: ~50-100MB RAM during scan
- CPU: Low during idle, moderate during scan (configurable throttle)
- Disk: ~500MB for manifests and logs

**Agent communication model:**
- Agent initiates all connections (no inbound ports required)
- Polls platform at regular intervals (configurable, default 4 hours)
- Receives scan manifests, configuration, and plugin updates
- Uploads scan results as XML

### Agent Assessment Modes

**Interval-based:**
- Agent runs full assessment every N hours (configurable: 1h minimum, default 4h)
- Assessment triggered at scheduled interval regardless of change activity
- Full vulnerability scan on each interval

**Continuous Monitoring:**
- Event-based triggers supplement interval scanning
- Software install/uninstall events trigger immediate partial assessment
- Configuration change events trigger compliance re-evaluation
- Reduces time-to-detect for new software vulns from hours to minutes

**On-demand:**
- Triggered from Qualys portal or API
- Assessment runs on next agent check-in (within polling interval)

### Agent Deployment Methods

**Mass deployment options:**
- **Windows:** Group Policy (GPO) + MSI, MECM/SCCM, Intune MDM
- **Linux:** Ansible playbook, Chef recipe, Puppet module, RPM/DEB package
- **Cloud:** AWS SSM, Azure Arc, cloud-init userdata, Terraform provider
- **Qualys-provided:** Qualys Cloud Agent deployment utility

**Activation IDs:**
- Each deployment can use the same or unique Activation ID
- Separate Activation IDs per environment (Prod, Dev, Test) for access control
- Activation IDs control which modules are enabled on agents

### Agent Health Monitoring

**Agent status states:**
- **Active:** Checking in within expected interval
- **Inactive:** Missed 2+ check-in intervals (likely offline or disconnected)
- **Deactivated:** Manually deactivated, no longer reporting
- **Pending Activation:** Agent installed but not yet activated

**QQL for agent health:**
```qql
# Agents not checked in for 7+ days
agentStatus.lastCheckedIn:[now-365d..now-7d]

# Agents with outdated version
agentVersion:[1..2.0.0]

# Agents not scanning (no detection data)
NOT vuln.severity:[1..5]
```

**Common agent issues:**
| Issue | Symptom | Fix |
|---|---|---|
| Connectivity blocked | No check-ins | Allow 443 to Qualys platform in firewall/proxy |
| Proxy misconfigured | Agent stuck | Set proxy in agent config file |
| Disk full | Scan failures | Free disk space, clean agent logs |
| Outdated agent | Missing detections | Upgrade via portal: Agents > Actions > Upgrade |
| Missing activation | No data | Re-activate with correct ActivationId |

## Scanner Appliance Architecture

### Virtual Appliance Types

| Appliance Type | Deployment | Use Case |
|---|---|---|
| **Virtual Scanner** | VMware, Hyper-V, KVM, VirtualBox | Primary on-premises scanning |
| **Physical Appliance** | Rack-mount hardware | High-throughput dedicated scanning |
| **Cloud Appliance** | AWS AMI, Azure Marketplace, GCP | Cloud network segment scanning |
| **PCI Scanner** | Any deployment | PCI DSS-certified ASV scanning |

**Sizing guidelines:**
- Small (< 500 assets per scan): 2 vCPU, 4GB RAM
- Medium (500-2,000 assets): 4 vCPU, 8GB RAM
- Large (2,000+ assets): 8 vCPU, 16GB RAM
- Disk: 100GB+ (OS + scan temp files + logs)

### Scanner Appliance Network Requirements

**Outbound (appliance to Qualys cloud):**
- Port 443/HTTPS to Qualys platform (qualysguard.qualys.com or platform-specific)
- For updates: Allow *.qualys.com on port 443

**Outbound (appliance to scan targets):**
- ICMP (ping for host discovery)
- TCP ports 1-65535 (full port scan)
- UDP ports (if UDP scanning enabled)
- Windows auth: TCP 135, 139, 445
- SSH: TCP 22
- SNMP: UDP 161

**Appliance management:**
- Web UI on port 443 (HTTPS) -- localhost access only
- No inbound connections required from outside

### Scanner Groups

Group scanners by location for scan routing:

```
Qualys Platform
    |
    +-- Scanner Group: Datacenter-A
    |       |-- Scanner-DC-A-01
    |       |-- Scanner-DC-A-02
    |
    +-- Scanner Group: Cloud-AWS-East
    |       |-- Scanner-AWS-East-01
    |
    +-- Scanner Group: Remote-Offices
            |-- Scanner-Denver-01
            |-- Scanner-London-01
```

Scan policies assign a scanner group, and Qualys load-balances across available scanners in the group.

## QQL Reference

### QQL Field Reference for VMDR

**Asset fields:**
```
id                          Asset ID
name                        Hostname
address                     IP address
os.name                     Operating system name
os.version                  OS version
cloud.provider              AWS, Azure, GCP, etc.
cloud.service               EC2, Azure VM, GCE, etc.
cloud.region                AWS/Azure/GCP region
tags.name                   Applied tag name
lastScanDate                Last vulnerability scan date
agentStatus.status          Agent status (Active, Inactive)
agentStatus.lastCheckedIn   Agent last check-in time
```

**Vulnerability fields:**
```
vulnerabilities.severity         1-5 (1=Info, 5=Critical)
vulnerabilities.qid              Qualys vulnerability ID
vulnerabilities.cveIds           CVE identifier
vulnerabilities.isKev            CISA KEV flag (true/false)
vulnerabilities.epss             EPSS score (0-1.0)
vulnerabilities.qds              QDS score (0-100)
vulnerabilities.firstFoundDate   When vuln was first detected
vulnerabilities.lastFoundDate    Most recent detection
vulnerabilities.title            Vulnerability name
vulnerabilities.status           ACTIVE, FIXED, REOPENED
```

**Date functions:**
```
now                          Current datetime
now-7d                       7 days ago
now-30d                      30 days ago
[start..end]                 Date range
```

### Common QQL Patterns

```qql
# Assets at critical risk (KEV + internet-facing)
vulnerabilities.isKev:true AND tags.name:"Internet-Facing"

# High-epss vulns on production assets
vulnerabilities.epss:[0.1..1.0] AND tags.name:"Production"

# Overdue critical vulns (open > 30 days, severity 5)
vulnerabilities.severity:5 AND vulnerabilities.firstFoundDate:[now-365d..now-31d] 
  AND vulnerabilities.status:ACTIVE

# Windows assets missing MS patches
os.name:"Windows" AND vulnerabilities.qid:[100000..109999]

# Unscanned cloud assets
cloud.provider:("AWS" OR "Azure") AND NOT lastScanDate:[now-30d..now]

# Log4Shell exposure
vulnerabilities.cveIds:"CVE-2021-44228" AND vulnerabilities.status:ACTIVE
```

## TotalCloud Architecture

### Connection Architecture

TotalCloud connects to cloud providers via read-only API access:

**AWS Connection:**
1. Deploy CloudFormation stack in each AWS account
2. Stack creates: IAM role with SecurityAudit + ReadOnlyAccess managed policies
3. Qualys assumes role via cross-account trust relationship
4. No agents required; scans run every 4 hours against AWS APIs

**Azure Connection:**
1. Register Qualys enterprise application in Azure AD
2. Assign Reader role at Management Group or Subscription scope
3. Grant API permissions: Microsoft.ResourceHealth/Read, Microsoft.Security/Read, etc.
4. Qualys pulls resource data every 4 hours

**GCP Connection:**
1. Create service account in GCP project
2. Assign roles: Viewer, Security Reviewer, Cloud Asset Viewer
3. Download JSON key file, upload to Qualys
4. Enable required GCP APIs: Cloud Asset API, Cloud Resource Manager API

### TotalCloud Data Flow

```
Cloud Provider APIs (AWS/Azure/GCP)
        |
        | Read-only API calls every 4h
        |
TotalCloud Connector
        |
        | Parse resource configurations
        |
Policy Engine
  - 1,000+ built-in CSPM controls
  - Custom FlexPolicies
  - Compliance frameworks
        |
        | Pass/fail per resource per control
        |
Posture Findings + CIEM + CWPP Results
        |
VMDR Integration (unified dashboard)
TruRisk scoring across cloud + on-prem
```

### TotalCloud Inventory

Resources discovered and tracked per cloud provider:

**AWS:** EC2 instances, VPCs, Security Groups, S3 Buckets, RDS instances, Lambda functions, ECS/EKS clusters, IAM users/roles/policies, CloudTrail, CloudWatch, KMS keys, Route53, ACM certificates, and 200+ resource types.

**Azure:** VMs, NSGs, Storage Accounts, SQL databases, AKS clusters, App Services, Key Vaults, Entra ID (users/service principals), Azure Monitor, and 150+ resource types.

**GCP:** Compute Engine, GKE, Cloud Storage, Cloud SQL, Cloud Functions, IAM, VPC, and 100+ resource types.

## Asset Inventory and CMDB Integration

### Qualys CSAM (Cyber Security Asset Management)

CSAM is the asset management hub for the Qualys platform:

**CSAM capabilities:**
- Unified asset inventory from all Qualys sensors (agents, scanners, cloud connectors)
- External attack surface (internet-exposed assets not in internal inventory)
- Asset lifecycle: Active, End-of-Life, Decommissioned tracking
- Software inventory (installed applications + version enumeration)
- CMDB integration: sync to ServiceNow, Jira Service Management

**External attack surface discovery:**
- Discovers internet-facing assets associated with the organization
- Uses domain names, IP ranges, certificate common names for attribution
- Finds shadow IT, acquired company assets, forgotten dev environments
- Correlates external findings with internal VMDR data

### CMDB Integration (ServiceNow)

Bidirectional sync between Qualys and ServiceNow CMDB:

**Qualys --> ServiceNow:**
- Asset records sync to ServiceNow CIs (Configuration Items)
- Vulnerability findings populate ServiceNow VR (Vulnerability Response) module
- TruRisk scores visible in ServiceNow asset context

**ServiceNow --> Qualys:**
- Asset criticality from CMDB flows to Qualys (enriches TruRisk)
- Business owner assignments sync to Qualys tags
- Remediation ticket status syncs back (closed in ServiceNow = rescan in Qualys)
