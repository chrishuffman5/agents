# Prisma Cloud / Cortex Cloud Architecture Reference

## Platform Architecture Overview

Prisma Cloud is a SaaS CNAPP delivered from Palo Alto Networks' cloud infrastructure. It uses a hybrid approach: agentless API scanning for posture management (CSPM/CIEM) and optional agent-based Defenders for deep workload protection (CWPP).

**Deployment model:**
- SaaS console hosted by Palo Alto Networks (multiple regions: US, EU, APAC, Canada, India)
- Customers connect cloud accounts via IAM roles/service principals (no inbound access to customer environments)
- Optional Defender agents deployed in customer workloads for runtime protection

## Data Collection Architecture

### CSPM: Agentless API Collection

```
Customer Cloud Account
  └── IAM Role / Service Principal (read-only)
        ↓ [API calls every ~60 minutes + change events]
Prisma Cloud SaaS
  └── API Ingestion Layer
        ├── Resource inventory (EC2, VMs, S3, storage, IAM, etc.)
        ├── Configuration state (security groups, policies, settings)
        ├── Network topology (VPC, subnets, routing, peering)
        └── Audit logs (CloudTrail, Activity Logs, GCP Audit)
  └── RQL Engine
        ├── Evaluates all config policies against collected data
        ├── Network graph analysis for exposure queries
        └── Generates alerts on policy violations
```

**Collection frequency:**
- Full resource scan: every 24 hours (configurable)
- Delta/change detection: near real-time via cloud event APIs (CloudTrail Event Bridge, Azure Event Hub, GCP Pub/Sub)
- Network flow analysis: VPC Flow Logs, NSG Flow Logs ingested from cloud storage

### CWPP: Defender Agent Architecture

The Defender is Prisma Cloud's CWPP agent. It provides deep workload telemetry that agentless approaches cannot match.

**Defender types:**

| Defender Type | Deployment | Use Case |
|---|---|---|
| Container (DaemonSet) | Kubernetes DaemonSet | EKS, AKS, GKE, self-managed K8s |
| Container (single) | Docker container | Docker hosts, non-orchestrated |
| Host | System service | Bare metal, VMs, EC2 without containers |
| Serverless | Lambda layer / Function extension | AWS Lambda, Azure Functions |
| App-Embedded | Embedded in container image | Fargate, App Runner, environments without node access |
| PCF | Buildpack / tile | Pivotal Cloud Foundry |

**Defender communication model:**
```
Workload (Defender Agent)
  └── Outbound WebSocket connection (TCP 443)
        ↓ [TLS 1.2+, certificate-pinned]
Prisma Cloud Console
  └── Defender Management Service
        ├── Real-time telemetry ingestion
        ├── Policy distribution to Defenders
        ├── Vulnerability database updates
        └── Runtime event storage and analysis
```

**No inbound ports required:** Defenders initiate outbound connections only. This means firewall rules only need to allow outbound HTTPS to the Prisma Cloud console URL.

**Defender data flows:**

1. **Vulnerability scan data:** Defender scans installed packages locally, sends package manifest to console, console performs CVE matching against vulnerability database
2. **Runtime events:** Process execution, file system events, network connections → streamed to console for analysis and alerting
3. **Compliance data:** Container/host configuration checks → sent to console for compliance reporting
4. **WAAS traffic:** In-line HTTP traffic analysis happens locally in Defender; only alerts sent to console

### CIEM: Identity Analysis Engine

**IAM data collection:**
- Prisma Cloud collects all IAM entities (users, roles, groups, service accounts, managed identities, OIDC providers, federated identities)
- Collects all attached policies (inline, managed, resource-based, SCPs, permission boundaries)
- Collects last-used timestamps for permissions (AWS: Service Last Accessed data, Azure: activity logs)

**Net-effective permissions calculation:**
Prisma Cloud's CIEM engine simulates IAM policy evaluation:

For AWS:
1. Check if there is an explicit Deny (from any policy source) → deny
2. Check for SCP allow boundary → if not in SCP allow, deny
3. Check permission boundary (if attached to role) → constrains allowed permissions
4. Check identity-based policies (inline + attached managed) → evaluate Allow statements
5. Check resource-based policy (for cross-account access) → requires both identity allow AND resource allow
6. Evaluate conditions (IP conditions, MFA required, time-of-day, etc.)

Result: "Can identity X perform action Y on resource Z?" with full reasoning.

**Overprivilege detection:**
- Compare granted permissions vs. actually-used permissions (from CloudTrail analysis)
- Identify permissions granted but never used in the last 90 days
- Generate "least privilege" replacement policy suggestions
- Calculate "excess privilege score" per identity

## Code Security (Checkov Integration)

### Checkov Open Source

Prisma Cloud Code Security is powered by Checkov — Palo Alto's open-source IaC scanner:

```
checkov -d ./terraform/              # scan directory
checkov -f main.tf                   # scan single file
checkov --check CKV_AWS_20           # run specific check
checkov --output sarif               # SARIF output for GitHub Code Scanning
checkov --soft-fail                  # don't fail on violations (reporting only)
```

**Check categories:**
- `CKV_AWS_*` — AWS resource checks
- `CKV_AZURE_*` — Azure resource checks
- `CKV_GCP_*` — GCP resource checks
- `CKV_K8S_*` — Kubernetes manifest checks
- `CKV_DOCKER_*` — Dockerfile checks
- `CKV2_*` — Graph-based checks (cross-resource relationships)

**Graph checks (CKV2):**
Checkov graph-based checks analyze relationships between resources, not just individual resources:
```python
# Example: Detect S3 bucket without corresponding bucket policy
PASS_GRAPH = [{
    "resource_type": "aws_s3_bucket",
    "connected_resources": [{
        "resource_type": "aws_s3_bucket_policy",
        "connection_type": "attribute",
        "attribute": "bucket"
    }]
}]
```

### Supply Chain Graph

Prisma Cloud's Supply Chain Graph visualizes the full software supply chain:
- Source code → build system → container image → deployment manifest → running service
- Identifies which source code change produced which running container
- Maps CVEs in running containers back to the specific code commit that introduced them
- Shows the full chain: developer commit → CI/CD pipeline → image registry → production deployment

## AppDNA Architecture

AppDNA correlates security findings with application context:

**Data sources:**
- Kubernetes labels (app, tier, component, owner)
- Deployment manifests (which pods belong to which service)
- Service mesh data (if Istio/Linkerd present)
- Tag-based grouping from cloud provider tags

**Application risk score:**
- Aggregates all vulnerability, alert, and incident findings per application
- Weights by severity, exploitability, and runtime context
- Provides application owners with an "application security posture" view

**Application owner workflows:**
- Application owners see only their application's security issues
- RBAC: developers see only their team's apps
- Application-level SLA tracking and reporting

## Cortex Cloud Convergence Architecture

### XDR Integration

Prisma Cloud runtime incidents (from CWPP Defenders) feed into Cortex XDR:

```
CWPP Defender (container/host)
  └── Runtime incident detected
        ↓ [via console integration]
Cortex XDR
  └── Incident correlation
        ├── Match cloud workload incident with endpoint telemetry
        ├── Correlate with network detections (from Cortex NDR)
        ├── Enrich with Threat Intelligence (AutoFocus, Unit 42)
        └── Unified incident timeline in XDR console
```

**Unified causality chain:**
XDR can show: "Phishing email received → user clicked link → browser download → lateral movement → cloud workload compromise → container escape → production database access" as a single incident.

### XSOAR Playbooks for Prisma Cloud

Pre-built Cortex XSOAR content packs for Prisma Cloud alerts:

**Auto-remediation playbooks:**
- `Prisma Cloud - S3 Public Access` — Automatically disables S3 public access, creates JIRA ticket for review
- `Prisma Cloud - EC2 Security Group Remediation` — Removes overly permissive inbound rules
- `Prisma Cloud - IAM Key Rotation` — Forces rotation of stale IAM access keys
- `Prisma Cloud - CloudTrail Alert` — Investigates CloudTrail-based behavioral alerts

**Workflow playbooks:**
- Alert triage and enrichment (resource context, owner lookup, business impact)
- Multi-approver remediation workflow for production resources
- False positive identification and suppression
- Escalation workflows based on severity and SLA

## Multi-Cloud Account Management

### Prisma Cloud Account Groups

Account Groups organize cloud accounts for:
- Alert routing (route alerts for prod accounts to SOC team, dev accounts to dev team)
- RBAC (grant access to specific account groups)
- Compliance reporting (separate compliance views per account group)
- Dashboard filtering (view posture for specific business unit)

**Common groupings:**
- By environment: Production, Staging, Development
- By business unit: Finance, Engineering, Marketing
- By region/geography: US-East, EU, APAC
- By cloud provider: AWS-accounts, Azure-subscriptions, GCP-projects

### Prisma Cloud Roles and RBAC

| Role | Capabilities |
|---|---|
| System Admin | Full access including settings, user management |
| Account Group Admin | Full access to assigned account groups |
| Account Group Read Only | View only for assigned account groups |
| Cloud Provisioning Admin | Onboard/manage cloud accounts only |
| Build and Deploy Security | Code security module only |
| DevSecOps | Read access to all modules; limited admin |

## API and Programmatic Access

### REST API

Prisma Cloud exposes a comprehensive REST API:

```bash
# Authenticate
curl -X POST "https://api.prismacloud.io/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"<access_key_id>","password":"<secret_key>"}'

# Get alerts
curl -X GET "https://api.prismacloud.io/alert?timeType=relative&timeAmount=24&timeUnit=hour&status=open" \
  -H "x-redlock-auth: <token>"

# Run RQL query
curl -X POST "https://api.prismacloud.io/search/config" \
  -H "x-redlock-auth: <token>" \
  -H "Content-Type: application/json" \
  -d '{"query":"config where cloud.type = '\''aws'\'' AND api.name = '\''aws-s3api-get-bucket-acl'\''","timeRange":{"type":"relative","value":{"unit":"hour","amount":24}}}'
```

### Prisma Cloud API Key Management

- API access uses access key + secret key (not user credentials)
- Keys have configurable expiry (30, 60, 90, 180, 365 days)
- Keys can be scoped to specific roles
- Keys managed in Settings → Access Keys

## Vulnerability Database

Prisma Cloud maintains its own vulnerability database (Intel Store) by aggregating from:
- NVD (National Vulnerability Database)
- Vendor advisories (Red Hat, Ubuntu, Alpine, Debian, Microsoft, etc.)
- GitHub Security Advisories
- Language-specific advisory databases (npm, PyPI, RubyGems, etc.)
- Palo Alto Unit 42 threat intelligence

**Update frequency:** Vulnerability database updated multiple times per day; new CVEs typically appear within hours of public disclosure.

**CVE context enrichment:**
- CVSS v2 and v3 scores
- CISA KEV (Known Exploited Vulnerabilities) status
- Exploit availability (Metasploit, PoC, weaponized)
- Affected package version ranges
- Fixed version recommendations
- Package-specific remediation guidance
