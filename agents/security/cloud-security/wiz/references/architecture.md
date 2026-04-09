# Wiz Architecture Reference

## Platform Overview

Wiz is a SaaS CNAPP platform that connects to customer cloud environments via read-only API connectors. All scanning infrastructure runs in Wiz's own cloud tenancy — customers never deploy scanning infrastructure into their environments (except the optional Wiz Defend runtime sensor).

**Google Acquisition (2025):** Wiz was acquired by Google for $32B. Wiz continues to operate as an independent multi-cloud product and is not limited to GCP.

## Agentless Scanning Architecture

### How Wiz Scans Without Agents

Wiz uses two complementary mechanisms:

**1. Cloud API Polling**
```
Customer Cloud Account
  └── IAM Role (ReadOnly)
        ↓ [AssumeRole via cross-account trust]
Wiz Platform (SaaS)
  └── API Collector Service
        ├── Lists all resources via AWS/Azure/GCP APIs
        ├── Reads configurations, policies, tags, relationships
        ├── Ingests change events (CloudTrail, Activity Logs, Pub/Sub)
        └── Feeds Security Graph builder
```

**2. Volume Snapshot Scanning**
```
Customer Cloud Account
  └── EBS Volume (running EC2 or container host)
        ↓ [CreateSnapshot API call via Wiz IAM role]
Wiz-owned AWS Account (same region)
  └── Temporary scan VM
        ├── Attaches snapshot as read-only volume
        ├── Mounts filesystem (ext4, XFS, NTFS)
        ├── Scans: package databases, file contents, secrets, malware
        └── Sends findings to Wiz platform
             → Snapshot deleted immediately after scan
```

**Snapshot scanning properties:**
- Zero performance impact on scanned workload
- Read-only — cannot modify customer data
- Snapshot lives in customer account (or Wiz account, depending on config) for minutes during scan
- Scanning happens in the same region as the source volume (data sovereignty)
- Supports: Linux (DEB, RPM, APK packages), Windows (MSI, WinGet), container images overlaid on host

### What Agentless Does NOT Cover

- Real-time process execution events (requires Wiz Defend sensor)
- Real-time network connections at the process level
- In-memory threats and fileless malware (requires runtime sensor)
- Container runtime activity (which container, which process, which syscalls)

## Security Graph Architecture

### Graph Data Model

The Security Graph is a property graph stored in a distributed graph database. Nodes have types and properties; edges have types and directionality.

**Core node types:**

| Type | Examples | Key Properties |
|---|---|---|
| CloudAccount | AWS Account, Azure Subscription, GCP Project | accountId, name, environment, tags |
| VirtualMachine | EC2 instance, Azure VM, GCE instance | instanceId, OS, status, publicIP, IMDS version |
| Container | Running container in ECS/EKS/AKS/GKE | containerId, image, namespace, pod |
| ContainerImage | ECR image, ACR image, Docker Hub image | digest, registry, tags, layers |
| ServerlessFunction | Lambda, Azure Function, Cloud Function | runtime, handler, triggers, environment vars |
| IAMEntity | IAM User, Role, Group, Service Account, Managed Identity | arn/id, attached policies, last used |
| IAMPolicy | AWS managed policy, inline policy, Azure role assignment | statements, actions, resources, conditions |
| DataStore | S3 bucket, Azure Blob, GCS bucket, RDS, DynamoDB, Azure SQL | name, access level, encryption, replication |
| Secret | Secrets Manager secret, Key Vault secret, environment variable | secretType, exposure, lastRotated |
| Network | VPC, Subnet, Security Group, NSG, Route Table | cidr, public/private, ingress/egress rules |
| Vulnerability | CVE | cveId, cvss, epss, hasPublicExploit, affectedPackage |
| DataFinding | Classification result | type (PII/PCI/PHI), confidence, recordCount |

**Core edge types (relationships):**

| Edge | From → To | Meaning |
|---|---|---|
| CONTAINS | CloudAccount → Resource | Account owns this resource |
| HAS_ROLE | VirtualMachine → IAMEntity | VM has this IAM role attached |
| HAS_PERMISSION | IAMEntity → Action:Resource | Net-effective permission |
| CAN_ASSUME | IAMEntity → IAMEntity | Can assume-role relationship |
| ACCESSIBLE_FROM | Network → VirtualMachine | Network exposure |
| EXPOSED_TO | VirtualMachine → Internet | Has public network path |
| HAS_VULNERABILITY | VirtualMachine/Image → Vulnerability | Affected by this CVE |
| STORES_DATA | DataStore → DataFinding | Contains classified sensitive data |
| HAS_SECRET | Resource → Secret | Secret found in this resource |
| COMMUNICATES_WITH | VirtualMachine → Resource | Observed or possible network connection |
| DEPLOYED_IN | Container → VirtualMachine | Container running on this host |
| USES_IMAGE | Container → ContainerImage | Container running this image |

### Graph Query Language (WQL)

Wiz uses WQL (Wiz Query Language) for custom rules and Explorer queries. WQL is a declarative graph traversal language:

**Basic structure:**
```
FIND <NodeType>
WHERE <conditions>
```

**Multi-hop traversal:**
```
FIND VirtualMachine
WHERE networkExposure = "WidelyOpen"  -- exposed to internet
  AND [HAS_VULNERABILITY]->(Vulnerability WHERE cvss >= 9.0 AND hasExploit = true)
  AND [HAS_ROLE]->(IAMRole)
  AND (IAMRole)-[HAS_PERMISSION]->(DataStore WHERE dataClassification = "PII")
```

**Aggregation:**
```
FIND CloudAccount
AGGREGATE COUNT(VirtualMachine WHERE networkExposure = "WidelyOpen") AS exposedVMs
ORDER BY exposedVMs DESC
```

**Common WQL patterns:**
- `networkExposure = "WidelyOpen"` -- accessible from internet with no restrictions
- `networkExposure = "Restricted"` -- accessible from internet with IP restrictions
- `isEndOfLife = true` -- operating system or software past end-of-life
- `hasPubliclyExposedSecret = true` -- secrets accessible from public endpoint
- `dataClassification IN ["PII", "PCI", "PHI"]` -- contains regulated data

## Toxic Combination Logic

### Multi-Factor Risk Scoring

Wiz evaluates toxic combinations using a multi-dimensional risk model:

```
Risk Score = f(
  Exploitability,     -- How easy is it to exploit the entry point?
  Blast Radius,       -- What can be reached after exploitation?
  Asset Value,        -- How valuable/sensitive is the target?
  Attack Path Length  -- How many steps to reach the target?
)
```

### Built-in Toxic Combination Detectors

Wiz ships pre-built toxic combination patterns:

**Category 1: Internet-Exposed + Exploitable + Privileged Identity**
- Public EC2/VM + Critical CVE with public exploit + IAM admin or write access to production

**Category 2: Credential Theft Path**
- Public workload + IMDSv1 enabled + High-privilege instance role
- IMDSv1 allows SSRF-based credential theft (e.g., Log4Shell + IMDS)

**Category 3: Data Exposure Chain**
- Any path from internet to sensitive data store (PII/PCI/PHI)
- Steps may include: exposed workload → lateral movement via IAM → sensitive bucket

**Category 4: Container Escape Path**
- Container with --privileged flag or dangerous capabilities + running as root + host path mount
- Combined with any further privilege escalation

**Category 5: Supply Chain Risk**
- Container image from public registry + critical CVE + running in production + internet-exposed

**Category 6: Identity-Based Attack Path**
- Over-privileged identity reachable from internet → assume role chain → privileged target

### Attack Path Visualization

In the Wiz console, attack paths display as a directed graph:

```
[Internet]
    |
    v [port 443 open, security group 0.0.0.0/0]
[EC2 Instance i-abc123]
    |-- OS: Ubuntu 20.04 (CVE-2023-XXXX CVSS 9.8, public exploit available)
    |-- IMDSv1: ENABLED
    |
    v [instance metadata credential theft]
[IAM Role: app-production-role]
    |-- Permissions: s3:GetObject, s3:PutObject, s3:DeleteObject on *
    |
    v [no bucket policy restriction]
[S3 Bucket: prod-customer-data]
    |-- 2.4M records
    |-- Data classification: PII (SSN, DOB, email, address)
    |-- No server-side encryption
    |-- No access logging
```

Each node in the visualization links to the resource in the Wiz console with remediation steps.

## Wiz Defend (Runtime Sensor)

### Architecture

Wiz Defend is an optional lightweight agent for runtime security:

**Deployment options:**
- DaemonSet for Kubernetes nodes (one pod per node)
- Standalone agent for standalone VMs/EC2 instances
- Container-native for ECS/GKE

**Kernel-level monitoring:**
- Uses eBPF (extended Berkeley Packet Filter) for low-overhead kernel event capture
- Captures: process execution, file system operations, network connections, syscalls
- No kernel module required — pure eBPF for modern kernels (4.14+)

**Event types captured:**
- Process spawn (exec family syscalls) with full argument capture
- File open/create/modify/delete for sensitive paths
- Network connect/accept with remote IP and port
- DNS queries
- Privilege escalation attempts (setuid, capabilities)

### CDR Detection (Cloud Detection and Response)

Wiz Defend enables behavioral threat detection:

**Detection categories:**
- **Crypto mining:** CPU-intensive processes, mining pool network connections, known mining binary hashes
- **Reverse shells:** Outbound network connection spawning a shell (bash/sh/zsh) over non-standard ports
- **Web shells:** Web server processes executing shell commands, suspicious child processes of web servers
- **Container escape:** Namespace manipulation, host filesystem access from container context
- **Credential theft:** Access to sensitive files (/etc/shadow, cloud credential paths), IMDS API calls
- **Lateral movement:** Internal network scanning, unusual SSH patterns, cloud API calls from unexpected workloads

**Integration with Security Graph:**
CDR detections in Wiz Defend are enriched with Security Graph context:
- Which cloud account/environment?
- What IAM permissions does this workload have?
- What sensitive data can this workload reach?
- Is this workload internet-exposed?

A detection becomes much more critical if the affected workload has a path to sensitive data.

## Multi-Cloud Coverage

### Supported Platforms

| Cloud | Coverage | Notes |
|---|---|---|
| AWS | Comprehensive | Deepest coverage; 400+ checks |
| Microsoft Azure | Comprehensive | 350+ checks; Azure AD/Entra ID identity analysis |
| Google Cloud | Comprehensive | 300+ checks; org-level connector supported |
| Oracle Cloud (OCI) | Good | Core compute, storage, IAM |
| Alibaba Cloud | Good | Core resources |
| GitHub/GitLab | Via Wiz Code | Source code, secrets, IaC |
| Kubernetes (on-prem) | Via Wiz for K8s | KubeAPI connector for self-managed clusters |
| VMware vSphere | Limited | Agentless scanning of on-prem VMs |

### AWS Organizations Integration

For multi-account AWS environments:
- Wiz supports AWS Organizations auto-discovery
- Master connector in management account auto-discovers and onboards member accounts
- Wiz CloudFormation StackSet deployed to all accounts in org
- Accounts automatically added to Wiz as they are created in the org

### Azure Management Groups

- Wiz connector at Management Group level
- Auto-discovers all subscriptions under the management group
- One App Registration with subscription-level access across all subscriptions

## Connector IAM Permissions

### AWS Permissions Required

```json
{
  "ReadOnly": "arn:aws:iam::aws:policy/ReadOnlyAccess",
  "SecurityAudit": "arn:aws:iam::aws:policy/SecurityAudit",
  "WizCustom": {
    "actions": [
      "ec2:CreateSnapshot",           // for volume scanning
      "ec2:CopySnapshot",             // cross-region snapshot copy
      "ec2:DescribeSnapshots",
      "ec2:DeleteSnapshot",
      "kms:CreateGrant",              // decrypt encrypted EBS volumes
      "s3:GetObject",                 // for DSPM data classification
      "s3:ListBucket",
      "ecr:GetDownloadUrlForLayer",   // container image scanning
      "ecr:BatchGetImage"
    ]
  }
}
```

### Key Security Properties of the Connector

- Cross-account role; Wiz never stores long-lived credentials
- External ID condition on trust policy prevents confused deputy attacks
- `ec2:CreateSnapshot` is the only write permission (only creates snapshots, cannot modify data)
- `s3:GetObject` can be restricted to specific buckets if full DSPM is not desired

## Wiz API and Programmatic Access

### GraphQL API

Wiz exposes a GraphQL API for programmatic access:

```graphql
query {
  issuesByEntityId(entityId: "i-abc123", entityType: VIRTUAL_MACHINE) {
    issues {
      id
      severity
      type
      entity { name, type }
      createdAt
      status
    }
  }
}
```

Common API use cases:
- Export findings to custom dashboards or BI tools
- Automated exception management based on tagging
- Custom risk scoring and prioritization logic
- Feeding findings into custom ticketing workflows

### Wiz CLI (wizcli)

Used for CI/CD integration:

```bash
# Scan a container image
wizcli docker scan --image myapp:latest --policy my-policy

# Scan IaC directory
wizcli iac scan --path ./terraform/ --policy high-severity

# Scan for secrets in code
wizcli dir scan --path ./src/ --type secrets

# Output formats: json, sarif, table
wizcli docker scan --image myapp:latest --format sarif --output results.sarif
```

`wizcli` returns non-zero exit codes on policy violations, enabling CI/CD gates.

## Deployment Topology

### Wiz SaaS Architecture

```
Customer Environments                    Wiz SaaS (Google Cloud)
┌─────────────────────┐                 ┌─────────────────────────┐
│ AWS Accounts        │                 │ API Collector            │
│  └── IAM Roles      │──[AssumeRole]──>│ Security Graph Builder   │
│                     │                 │ Risk Correlation Engine  │
│ Azure Subscriptions │                 │ Compliance Engine        │
│  └── Service Prin.  │──[OAuth2]──────>│ DSPM Classifier          │
│                     │                 │ CDR Analytics            │
│ GCP Projects        │                 │                          │
│  └── Service Accts  │──[SA Key/WI]───>│ Wiz Console (HTTPS)      │
│                     │                 │ Wiz API (GraphQL)        │
│ [EBS Snapshots]─────────────────────>│ Snapshot Scan Workers    │
└─────────────────────┘                 └─────────────────────────┘
```

### Data Residency

- Wiz offers US and EU data residency
- Snapshots are scanned in the same region as the source (no cross-region data transfer for raw data)
- Metadata (findings, graph data) resides in Wiz's SaaS region
- GDPR and FedRAMP considerations: Wiz has FedRAMP Moderate authorization
