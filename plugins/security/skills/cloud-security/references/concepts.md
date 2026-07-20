# Cloud Security Concepts Reference

## Shared Responsibility Model

### The Fundamental Split

Cloud providers guarantee the security **of** the cloud — physical infrastructure, hardware, hypervisor, global network, and the underlying managed services. Customers are responsible for security **in** the cloud — everything they configure, deploy, and operate.

**AWS Shared Responsibility:**
- AWS owns: global infrastructure, hardware, networking, managed service platforms (RDS engine, S3 service, Lambda runtime)
- Customer owns: OS configuration (for EC2), network configuration (VPCs, security groups, NACLs), IAM configuration, data encryption, application security, workload deployment

**Azure Shared Responsibility:**
- Microsoft owns: physical, network, hypervisor
- Shared: OS (for PaaS), network controls (for SaaS)
- Customer owns: identity/directory, applications, data, devices, accounts

**GCP Shared Responsibility:**
- Similar to AWS; GCP provides strong defaults (e.g., service accounts per-project, OS Login, org policies)

**Key insight:** The #1 cause of cloud security incidents is customer misconfiguration, not provider failure. CSPM tools exist to continuously validate customer-owned configuration.

### Responsibility by Service Type

| Service Type | Example | OS | Network Config | IAM | App Security | Data |
|---|---|---|---|---|---|---|
| IaaS | EC2, Azure VM, GCE | Customer | Customer | Customer | Customer | Customer |
| PaaS | RDS, App Service, Cloud Run | Shared | Shared | Customer | Customer | Customer |
| SaaS | Microsoft 365, Salesforce | Provider | Provider | Customer | Provider | Shared |
| Serverless | Lambda, Azure Functions | Provider | Shared | Customer | Customer | Customer |
| Containers | ECS, AKS, GKE | Shared | Shared | Customer | Customer | Customer |

## CNAPP: Cloud-Native Application Protection Platform

### Definition and History

Gartner coined CNAPP in 2021 to describe the convergence of CSPM, CWPP, and related cloud security tools into a unified platform. The key insight: cloud security tools were proliferating and creating silos. A CNAPP provides correlated context across posture, workload, identity, and data.

**The problem CNAPP solves:** Individual tools find individual issues in isolation. A misonfigured S3 bucket is low severity. An EC2 instance with a critical CVE is medium severity. But an EC2 with an exploitable CVE, instance metadata accessible, and an IAM role that can read that S3 bucket containing PII is a critical attack path — a "toxic combination." Only a unified platform with a graph model can see this.

### CNAPP Capability Taxonomy

**CSPM (Cloud Security Posture Management)**
- Continuously scans cloud resource configurations against security benchmarks
- Works by reading cloud provider APIs (no agents needed)
- Coverage: IAM policies, network configurations, storage permissions, encryption settings, logging/monitoring configuration, service-specific settings
- Benchmarks: CIS Foundations (AWS, Azure, GCP), NIST 800-53, SOC 2, PCI DSS, ISO 27001, HIPAA, FedRAMP
- Key metrics: number of open findings by severity, compliance score per framework, mean time to remediate

**CWPP (Cloud Workload Protection Platform)**
- Protects workloads — VMs, containers, serverless functions, databases
- Two approaches:
  - **Agentless:** Snapshot-based scanning (read cloud storage snapshots without running in the workload). Low coverage for runtime, high coverage for vulnerability detection.
  - **Agent-based:** Runtime agent installed in workload. Full runtime visibility, behavioral detection, process monitoring. Requires deployment and maintenance.
- Capabilities: vulnerability scanning (OS packages, language libraries), malware detection, runtime behavioral monitoring (process execution, file system changes, network connections), drift detection

**CIEM (Cloud Infrastructure Entitlement Management)**
- Analyzes all IAM entities (users, roles, groups, service accounts, federated identities) and their permissions
- Calculates **net-effective permissions** — the actual permissions after evaluating all attached policies, permission boundaries, SCPs, resource policies, and conditions
- Identifies: over-privileged identities, stale/unused credentials, cross-account trust relationships, privilege escalation paths, shadow admin accounts
- Key concept: **least privilege** — grant only the permissions needed for a specific task

**DSPM (Data Security Posture Management)**
- Discovers data stores across the cloud estate (S3 buckets, RDS databases, Blob storage, BigQuery datasets, DynamoDB tables, etc.)
- Classifies data by sensitivity (PII, PCI, PHI, secrets, IP)
- Maps data exposure: who/what has access, is data encrypted, is data publicly accessible, is there logging
- Identifies **shadow data** — data stores unknown to security teams
- DSPM is newer than CSPM/CWPP/CIEM and is still maturing

**CDR (Cloud Detection and Response)**
- Real-time threat detection and response across cloud telemetry
- Sources: cloud audit logs (CloudTrail, Activity Logs, Cloud Audit Logs), workload telemetry (agent-based), network flow logs (VPC Flow Logs, NSG Flow Logs), identity events
- Detection approach: behavioral analytics, anomaly detection, threat intelligence, rule-based detection
- Techniques: credential exfiltration detection, unusual API patterns, lateral movement via role assumption, crypto mining signatures

**AI-SPM (AI Security Posture Management)**
- Newest category (2024+)
- Discovers AI/ML workloads: SageMaker models, Azure OpenAI deployments, Vertex AI, custom model endpoints
- Identifies AI-specific risks: exposed model endpoints, training data in accessible storage, prompt injection surfaces, model exfiltration risks
- Classifies AI data flows and permissions

**Shift-Left / Code Security**
- IaC scanning (Terraform, CloudFormation, ARM, Bicep, Pulumi) for misconfigurations before deployment
- Secrets detection in source code (API keys, credentials hardcoded)
- SCA (Software Composition Analysis) — vulnerable dependencies in application code
- Container image scanning in CI/CD (before images reach production)
- CI/CD pipeline security (GitHub Actions, GitLab CI, Jenkins)

## Cloud Security Posture: Key Misconfiguration Categories

### Storage
- Public S3 buckets / Azure Blob containers / GCS buckets
- S3 bucket policies granting public access or cross-account access without conditions
- Unencrypted storage volumes (EBS, Azure Disk, GCP PD)
- Missing access logging on storage buckets
- S3 Object Lock / WORM not configured for regulated data

### Networking
- Security groups / NSGs allowing inbound 0.0.0.0/0 on SSH (22), RDP (3389)
- Overly permissive security groups on databases (allow from anywhere)
- VPC peering connections with overly broad routing
- Internet-exposed management ports
- Missing VPC Flow Logs

### Identity and Access Management
- Root account / global admin usage (no MFA, active credentials)
- IAM users with programmatic access keys not rotated
- Overly permissive IAM policies (wildcards: `*` actions and resources)
- Cross-account role trust relationships without conditions
- Missing MFA enforcement
- Long-lived credentials (service account keys, IAM access keys) instead of short-lived tokens

### Compute
- EC2 instances with IMDSv1 enabled (allows SSRF-based credential theft)
- Unpatched OS with critical CVEs
- Public AMIs with sensitive data
- EC2 instances in public subnets without necessity
- Missing endpoint protection

### Data
- Unencrypted databases
- Database snapshot sharing to public or unintended accounts
- Missing database encryption in transit
- S3 buckets with sensitive data without server-side encryption
- Secrets stored in environment variables instead of secrets managers

### Logging and Monitoring
- CloudTrail disabled or not logging management events
- CloudTrail log validation disabled
- Missing GuardDuty / Defender / Security Command Center
- No alerting on root account activity
- No alerting on IAM policy changes

## Cloud Compliance Frameworks

### CIS Benchmarks
- CIS AWS Foundations Benchmark — 3 levels (Level 1 basic, Level 2 enhanced, Level 3 high security)
- CIS Azure Foundations — similar structure
- CIS GCP Foundations
- Widely used as the baseline CSPM assessment framework

### NIST Standards
- NIST 800-53 — Federal information systems; comprehensive control catalog
- NIST 800-190 — Container security guidance
- NIST CSF 2.0 — Risk management framework (Govern, Identify, Protect, Detect, Respond, Recover)

### Industry Frameworks
- **PCI DSS 4.0** — Payment card data; cloud-specific guidance added in v4
- **HIPAA** — PHI protection; cloud BAAs and configuration requirements
- **SOC 2 Type II** — Trust service criteria (Security, Availability, Processing Integrity, Confidentiality, Privacy)
- **ISO 27001** — Information security management; Annex A controls map to cloud

### Cloud-Specific
- **AWS Well-Architected Security Pillar** — AWS best practices for secure architecture
- **Azure Security Benchmark** — Microsoft's security guidance for Azure
- **Google Cloud Security Foundations** — GCP security architecture guidance
- **FedRAMP** — US federal cloud authorization program

## Cloud Attack Path Analysis

### The Attack Path Model

An attack path represents the sequence of steps an adversary could take from an initial foothold to a high-value target. Modern CNAPP platforms model this as a directed graph:

```
[Internet] --> [Exploitable EC2 vulnerability]
           --> [IMDS credential theft (IMDSv1)]
           --> [EC2 instance role]
           --> [AssumeRole to privileged role]
           --> [S3:GetObject on sensitive bucket]
           --> [PII data exfiltration]
```

### Toxic Combinations

A toxic combination (Wiz terminology) or "attack path" is the combination of risk factors that together create a critical security issue, even if individually each factor might be acceptable:

Common toxic combination patterns:
- **Exposed + Vulnerable + Privileged:** Public-facing resource + critical CVE + IAM role with broad permissions
- **Exposed + Sensitive Data:** Public-facing storage + sensitive data classification
- **Lateral Movement Chain:** Overprivileged identity + cross-account trust + target account sensitive resource
- **Credential Theft Path:** IMDSv1-enabled compute + high-privilege instance role + sensitive target
- **Shadow Access:** Service account with unused but broad permissions + public workload using that account

### MITRE ATT&CK for Cloud (IaaS, SaaS, Azure AD, GCP, AWS, Office 365)

MITRE maintains cloud-specific ATT&CK matrices. Key cloud-specific techniques:

**T1552 - Unsecured Credentials:**
- .004: Cloud Instance Metadata API (steal credentials from IMDS)
- .008: Chat Messages (credentials in Slack/Teams)

**T1078 - Valid Accounts:**
- .004: Cloud Accounts (compromised IAM users/service accounts)

**T1098 - Account Manipulation:**
- .001: Additional Cloud Credentials (add access keys to compromised account)
- .003: Additional Cloud Roles (attach policies to gain persistence)

**T1136 - Create Account:**
- .003: Cloud Account (create new IAM user for backdoor access)

**T1537 - Transfer Data to Cloud Account:**
- Exfiltrate data by creating S3 bucket in attacker account and replicating data

## CSPM vs. CWPP vs. CIEM: Decision Guide

**Start with CSPM if:**
- You are new to cloud security and don't have visibility into your posture
- You need compliance evidence for audits
- You want the fastest time-to-value with agentless deployment

**Add CWPP when:**
- You need vulnerability data on running workloads (CVEs in deployed packages)
- You need runtime behavioral detection (detecting active attacks in workloads)
- You have containers and need image scanning + admission control

**Add CIEM when:**
- IAM complexity is high (large number of accounts, roles, federated identities)
- You have experienced or are worried about privilege escalation attacks
- Audit requirements demand least-privilege evidence

**Add DSPM when:**
- You handle sensitive regulated data (PII, PCI, PHI)
- You need to demonstrate data governance to auditors
- You suspect there is sensitive data in places security doesn't know about

**Full CNAPP when:**
- You want correlated, contextual risk (toxic combinations, attack paths)
- You have multi-cloud complexity
- You want to reduce security tool sprawl

## Cloud Security Program Maturity Model

### Level 1: Visibility
- CSPM deployed, basic benchmark scanning
- CloudTrail / Activity Logs / Cloud Audit Logs enabled
- Centralized logging (Security Hub, Sentinel, SIEM)
- Basic alerting on critical misconfigurations

### Level 2: Risk Reduction
- CSPM findings triaged and being remediated
- Vulnerability scanning on workloads
- CIEM analysis identifying most overprivileged identities
- Automated remediation for high-confidence CSPM findings
- CI/CD security scanning (IaC, image scanning)

### Level 3: Proactive Defense
- Full CNAPP platform with attack path analysis
- CWPP with runtime protection
- CDR with behavioral threat detection
- DSPM covering regulated data stores
- Developer security training and shift-left adoption

### Level 4: Optimized
- AI-driven risk prioritization (only fix what matters)
- Automated remediation with guardrails
- Continuous compliance posture measurement
- Threat intelligence integration
- Red team / cloud pen testing program
