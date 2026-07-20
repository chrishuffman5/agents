# Microsoft Defender for Cloud Architecture Reference

## Platform Architecture Overview

Defender for Cloud is a cloud-native CSPM and workload protection platform built natively into Azure. It consists of:
- A control plane hosted by Microsoft (the Defender for Cloud service)
- Log Analytics agent or Azure Monitor Agent (AMA) deployed to VMs for monitoring
- Defender sensors deployed to Kubernetes clusters (DaemonSet)
- Azure Policy engine for configuration assessment
- Microsoft Defender for Endpoint (MDE) integration for deep endpoint protection

## Data Collection Architecture

### CSPM: Policy-Based Assessment

Defender for Cloud uses Azure Policy as its assessment engine:

```
Azure Resources
  └── Azure Resource Manager (ARM)
        ↓ [ARM reads resource configurations]
Azure Policy Engine
  └── Policy assignments (Defender for Cloud initiative)
        ├── Evaluates resource configurations against policy rules
        ├── Marks resources as Compliant / Non-Compliant
        └── Creates Defender for Cloud recommendations from non-compliant resources
Defender for Cloud
  └── Aggregates policy results as security recommendations
  └── Calculates secure score from recommendation health
```

**Assessment frequency:**
- Policy compliance evaluated continuously
- New resources assessed within minutes of creation
- Recommendation state updated every few hours
- Secure score updated near real-time

**Policy initiative structure:**
Defender for Cloud's built-in policies are packaged as "security initiatives":
- "Microsoft cloud security benchmark" — the default initiative applied to all subscriptions
- Regulatory compliance initiatives (CIS, PCI DSS, NIST, etc.) applied separately
- Custom initiatives for custom compliance frameworks

### CWPP: Data Collection Agent Options

For workload protection (Defender for Servers), Defender for Cloud can use two agent types:

**Log Analytics Agent (legacy, being deprecated):**
- Windows: MicrosoftMonitoringAgent.msi service
- Linux: omsagent
- Data sent to Log Analytics Workspace
- Being replaced by Azure Monitor Agent (AMA)

**Azure Monitor Agent (AMA, current):**
- Replaces Log Analytics Agent as primary collection mechanism
- Configured via Data Collection Rules (DCRs)
- More granular control over what data is collected and where it's sent
- Supports multi-homing (send data to multiple workspaces)
- Auto-provisioning: Defender for Cloud can auto-deploy AMA to all VMs in scope

**What agents collect:**
- Windows Security Events (for threat detection)
- Syslog (Linux, for threat detection)
- Performance counters
- File integrity monitoring events
- Process execution events (for adaptive application controls)
- Network connection events

### MDE Integration Architecture

Defender for Servers Plan 1 and Plan 2 include Microsoft Defender for Endpoint (MDE):

```
Azure VM / Arc Server
  └── MDE Sensor (installed by Defender for Cloud auto-provisioning)
        ↓ [HTTPS to MDE cloud service]
Microsoft Defender for Endpoint (MDE)
  └── Threat detections → forwarded to Defender for Cloud alerts
  └── Vulnerability data (MDVM) → forwarded to Defender for Cloud recommendations
  └── Device inventory → accessible via Defender for Cloud asset inventory
```

**MDE auto-provisioning:**
When Defender for Servers is enabled, Defender for Cloud can auto-provision the MDE sensor to all eligible VMs in scope (Azure VMs + Arc servers). No manual installation needed.

**MDE on non-Azure (via Arc):**
1. Install Azure Connected Machine agent (Arc) on non-Azure VM
2. Enable Defender for Servers on the Arc subscription
3. Defender for Cloud auto-provisions MDE sensor
4. Full MDE protection on AWS EC2, GCP GCE, on-prem servers

## Defender for Containers Architecture

### AKS (Native)

For AKS, Defender for Containers is deeply integrated:

```
AKS Cluster
  └── Azure Kubernetes Service
        ├── Kubernetes audit logs → Azure Monitor → Defender analysis
        ├── Defender profile (DaemonSet) deployed automatically
        │     └── Captures runtime events → Defender for Cloud threat detection
        ├── ACR (Azure Container Registry)
        │     └── Images scanned on push → vulnerability findings
        └── Azure Policy for Kubernetes (Gatekeeper OPA)
              └── Enforces pod security policies, image source restrictions
```

**Defender profile (DaemonSet) capabilities:**
- Collects kernel-level events via eBPF
- Process execution, network connections, file system access within containers
- Events analyzed by Defender for Cloud for behavioral threats
- Sends compressed telemetry to Defender for Cloud (minimal bandwidth)

### Arc-Enabled Kubernetes

For non-AKS clusters (EKS, GKE, self-managed):

```
Non-AKS Kubernetes Cluster
  └── Azure Arc-enabled Kubernetes
        ├── Arc cluster connect agent (outbound only)
        └── Defender for Containers extension (DaemonSet)
              └── Same capabilities as AKS Defender profile
              └── Kubernetes audit log shipped via Azure Monitor
```

**Requirements:**
- Azure Arc-enabled Kubernetes agent must be installed on the cluster
- Defender for Containers extension deployed as Helm chart
- Outbound network access to Azure Monitor and Defender endpoints

### Container Registry Scanning Architecture

```
Container Registry (ACR, or connected ECR/GCR)
  └── On image push (trigger) or scheduled scan
        ↓ [Defender for Cloud pulls image]
Microsoft Defender Vulnerability Management (MDVM)
  └── Image layer scanning
        ├── OS package CVE detection
        ├── Application package CVE detection
        └── Findings → Defender for Cloud recommendations
```

**Connected non-ACR registries:**
- AWS ECR: connected via AWS connector
- GCP GCR: connected via GCP connector
- Docker Hub: manual connection via registry credentials

## Regulatory Compliance Assessment Engine

### How Compliance Is Assessed

Regulatory compliance in Defender for Cloud is a layered mapping:

```
Azure Policy Rules
  └── Grouped into Policy Initiatives (one per standard)
        └── Each policy maps to one or more compliance controls
              └── Defender for Cloud shows control status = pass/fail based on policy results
```

**Control status logic:**
- A control passes if ALL policies mapped to it are compliant for ALL in-scope resources
- Partial compliance (some resources pass, some fail) → control marked as failing
- Resources with exemptions → excluded from assessment

**Regulatory compliance initiative assignment:**
```
Azure Portal → Defender for Cloud → Regulatory Compliance → Manage Compliance Policies
→ Select subscription scope
→ Add standard (e.g., "NIST SP 800-53 R5")
→ Creates a Policy Initiative assignment at subscription scope
→ Assessment appears in Regulatory Compliance dashboard within 24 hours
```

### Compliance Evidence

For audit purposes, Defender for Cloud generates compliance evidence:
- Per-control assessment: list of assessed resources, policy that assessed them, pass/fail
- PDF report: compliance posture at a point in time
- Continuous export: push compliance state changes to Log Analytics or Event Hub for retention

## Azure Arc Architecture for Multi-Cloud

### Azure Arc Connected Machine Agent

```
Non-Azure Resource (AWS EC2, on-prem VM, GCP GCE)
  └── Azure Connected Machine Agent
        ├── Outbound HTTPS (TCP 443) to Azure endpoints
        ├── Uses managed service identity (MSI) for authentication
        └── Registers as Azure resource in a designated Resource Group
Azure Resource Graph
  └── Arc-connected machine appears as resource type:
      Microsoft.HybridCompute/machines
Defender for Cloud
  └── Reads Arc machines from Resource Graph
  └── Applies recommendations, policies, and Defender plans
```

**Arc agent capabilities:**
- Azure VM extensions (deploy AMA, MDE, custom scripts)
- Azure Policy (apply and assess against machines)
- Azure Monitor (collect logs and metrics)
- Azure Key Vault certificate management
- Azure Update Manager (patch management)
- Defender for Cloud (CSPM + CWPP via Defender for Servers)

### AWS Native Connector (Without Arc)

For CSPM-only coverage of AWS without deploying Arc agents:

```
AWS Account
  └── IAM Role (cross-account, read-only)
        └── Defender for Cloud connector reads:
              ├── AWS Config resource configurations
              ├── AWS Security Hub findings
              ├── CloudTrail audit events (selected)
              └── EC2, S3, IAM inventory via API
Defender for Cloud
  └── Imports Security Hub findings as Defender alerts
  └── CSPM recommendations for AWS resources (via Azure Policy mapped to AWS config rules)
  └── Shows AWS resources in asset inventory alongside Azure resources
```

## Log Analytics Workspace Relationship

Defender for Cloud has a complex relationship with Log Analytics Workspaces (LAW):

**Default workspace:**
- Defender for Cloud auto-creates a default workspace per region (named `defaultworkspace-<subscriptionId>-<region>`)
- Agent-collected data (events, syslog) goes to this workspace
- Defender for Cloud queries this workspace for threat detection

**Custom workspace:**
- Can configure Defender for Cloud to use a customer-managed workspace
- Required for: combining security data with other operational logs, controlling data retention, cost management

**Data stored in workspace (security-relevant tables):**
- `SecurityEvent` — Windows Security Events (login, process, policy changes)
- `Syslog` — Linux syslog events
- `SecurityAlert` — Defender for Cloud alerts
- `SecurityRecommendation` — Recommendations state snapshots
- `AzureActivity` — Azure control plane audit log
- `AuditLogs` / `SigninLogs` — Entra ID events (separate connector)
- `WindowsFirewall` / `LinuxFirewall` — Firewall log data

## Defender Plans Pricing Model

Defender for Cloud plans are billed per resource per plan per month:

| Plan | Billing Unit | Typical Cost |
|---|---|---|
| Defender CSPM | Per billable resource | ~$0.007/resource-hour |
| Defender for Servers P1 | Per server/month | ~$5/server/month |
| Defender for Servers P2 | Per server/month | ~$15/server/month |
| Defender for Containers | Per vCore/hour | Varies by cluster size |
| Defender for SQL (Azure SQL) | Per instance/month | ~$15/instance/month |
| Defender for SQL (SQL on VMs) | Per server/month | ~$15/server/month |
| Defender for Storage | Per storage account + per-transaction | Varies |
| Defender for Key Vault | Per 10K transactions/month | ~$0.02 per 10K |
| Defender for App Service | Per App Service plan/month | ~$15/plan/month |
| Defender for DNS | Per 1M queries | ~$0.20/1M |

**Cost management tips:**
- Enable plans only where needed (can scope to resource group or tag-based exclusions)
- Defender for Servers: start with Plan 1 for MDE integration + JIT; upgrade to Plan 2 for full CWPP
- Use Management Group policy to enforce consistent plan enablement across all subscriptions

## Workflow: Alert to Incident

```
Azure Resource Event / Agent Telemetry
  ↓
Defender for Cloud Analysis Engine
  ├── Rule-based detection
  ├── ML-based anomaly detection
  └── Threat intelligence correlation (Microsoft TI feeds)
  ↓
Security Alert created (in Defender for Cloud)
  ↓
Microsoft Sentinel (if connected via native connector)
  └── Alert ingested as SecurityAlert record
  └── Sentinel Fusion correlates with other signals
  └── Incident created (if correlation matches an Analytics rule)
  ↓
Automated Response
  ├── Logic App triggered by alert (automation rules)
  ├── Sentinel Playbook (Logic App) for complex workflows
  └── Azure Auto-Remediation Task (for recommendation-based automation)
```

## Defender for Cloud Security Graph (Enhanced CSPM)

With Defender CSPM plan enabled, Defender for Cloud builds a security graph similar to Wiz's Security Graph:

**Security Explorer:**
- Graph-based query interface
- Traverse relationships between resources, identities, data, and network topology
- Query examples:
  - "Find VMs exposed to internet with critical vulnerabilities"
  - "Find storage accounts containing sensitive data accessible from public network"
  - "Find identities with admin permissions that haven't used them in 90 days"

**Attack path analysis:**
- Pre-built attack path templates for common cloud attack scenarios
- Surfaces: internet-exposed VM with CVE + IAM role with sensitive data access
- Displays remediation path (fix the weakest link to break the attack path)
- Attack paths viewable as graph visualization in Azure Portal

**Cloud Security Graph data model:**
- Resource nodes: VMs, storage, databases, identities, networks, containers
- Edge types: network exposure, IAM permission, data storage relationship
- CVE data: from MDVM vulnerability assessments
- Data classification: from Defender DSPM capabilities
