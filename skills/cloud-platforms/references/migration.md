# Cloud Migration Strategy

> 7 Rs framework, migration sequencing, tools by cloud provider, data migration patterns, and cross-cloud migration considerations.

---

## The 7 Rs Framework

Each application in a migration portfolio should be assigned one of these strategies based on business value, technical complexity, and organizational readiness.

### 1. Retire (Decommission)

Shut down applications no longer needed. Duplicate functionality, no active users, technical debt not worth carrying. Effort: low (requires business sign-off and data archival). Typical: 10-20% of portfolio.

### 2. Retain (Revisit Later)

Keep in current environment. Recently upgraded on-prem, regulatory constraints, nearing end-of-life, too complex to move now. Revisit on a schedule -- "retain" can become "ignore."

### 3. Rehost (Lift and Shift)

Move as-is to cloud VMs with minimal changes. Fast but doesn't leverage cloud-native benefits. Often results in higher cloud costs than on-prem without optimization. Tools: AWS Application Migration Service (MGN), Azure Migrate, GCP Migrate for Compute Engine.

### 4. Relocate (Hypervisor-Level Lift and Shift)

Move VMware VMs to cloud VMware environment without re-platforming. Low effort. Options: VMware Cloud on AWS, Azure VMware Solution, Google Cloud VMware Engine.

### 5. Replatform (Lift, Tinker, and Shift)

Make targeted optimizations during migration without changing core architecture. Examples: self-hosted PostgreSQL to RDS/Cloud SQL, self-hosted Kafka to managed Kafka, custom deployment to container orchestration. Medium effort.

### 6. Refactor / Re-architect

Redesign to be cloud-native. Microservices, serverless, event-driven. Best long-term results but highest cost and risk. Reserve for strategic applications with strong business case.

### 7. Repurchase (Replace with SaaS)

Replace custom/on-prem software with SaaS equivalent. Examples: on-prem Exchange to O365, on-prem CRM to Salesforce, self-hosted monitoring to Datadog. Medium effort (data migration + user training).

### Quick Decision Tree

```
Is the app still needed?
  NO --> RETIRE
  YES -> Can it be replaced by SaaS?
    YES, meets requirements --> REPURCHASE
    NO -> Does it need architectural changes?
      YES, major --> REFACTOR (if business case justifies)
      YES, minor --> REPLATFORM
      NO -> Is it on VMware?
        YES --> RELOCATE (VMware-to-VMware)
        NO  --> REHOST (lift and shift)
Too complex or risky to move now?
  YES --> RETAIN (revisit in 6-12 months)
```

---

## Migration Sequencing

### Four-Phase Approach

1. **Assess** -- Build application inventory, classify by 7 Rs, identify dependencies, map to migration waves.
2. **Mobilize** -- Set up landing zone, networking (VPN/Direct Connect/ExpressRoute/Interconnect), security baseline, CI/CD for infrastructure.
3. **Migrate in waves** -- Start with low-risk, well-understood applications. Build confidence and skills. Increase complexity over waves.
4. **Optimize post-migration** -- Right-size, implement auto-scaling, enable managed services, address performance issues discovered in cloud.

### Wave Planning Guidance

- **Wave 1:** Simple stateless applications with few dependencies. Low risk, high confidence building.
- **Wave 2:** Applications with basic database dependencies. Validate database migration tooling.
- **Wave 3:** Complex applications with multiple service dependencies. Test interconnectivity.
- **Wave 4:** Mission-critical applications. Apply all lessons learned from previous waves.
- **Wave 5:** Legacy or complex applications (mainframe, tightly coupled). Longest timeline.

---

## Migration Tools by Cloud

### AWS Migration Tools

| Tool | Purpose |
|------|---------|
| Migration Hub | Central tracking dashboard for all migrations |
| Application Migration Service (MGN) | Automated rehost of servers (replaces CloudEndure) |
| Database Migration Service (DMS) | Continuous database replication for migration |
| Schema Conversion Tool (SCT) | Convert database schemas between engines |
| DataSync | High-speed data transfer to/from AWS |
| Snow Family (Snowball, Snowcone, Snowmobile) | Physical data transfer for large datasets |
| Transfer Family | Managed SFTP/FTPS/FTP for S3 and EFS |
| Migration Evaluator | Build business case for migration (TCO analysis) |

### Azure Migration Tools

| Tool | Purpose |
|------|---------|
| Azure Migrate | Central hub: discovery, assessment, migration of servers, databases, web apps |
| Database Migration Service | Online and offline database migration |
| Data Box (Disk, Standard, Heavy) | Physical data transfer devices |
| AzCopy | High-performance command-line data transfer |
| Azure Site Recovery | Disaster recovery and rehost migration |
| Azure Migrate: App Containerization | Containerize ASP.NET and Java web apps |
| Storage Migration Service | Migrate file servers to Azure |
| Total Cost of Ownership Calculator | Build business case for Azure migration |

### GCP Migration Tools

| Tool | Purpose |
|------|---------|
| Migrate for Compute Engine | Automated VM migration with minimal downtime |
| Database Migration Service | Managed migration for MySQL, PostgreSQL, SQL Server to Cloud SQL / AlloyDB |
| Transfer Service | Online data transfer from on-prem, other clouds, or internet sources |
| Transfer Appliance | Physical data transfer device for large datasets |
| Migrate for Anthos | Containerize and migrate VMs to GKE |
| BigQuery Data Transfer Service | Automated data loading into BigQuery |
| Cloud Foundation Toolkit | IaC templates for landing zone setup |
| Rapid Migration Program (RaMP) | Methodology and tools for accelerated migration |

---

## Data Migration Patterns

### Online vs. Offline Migration

**Online (network-based):** Continuous replication over network. Best for databases and active file systems. Tools: DMS (all clouds), DataSync (AWS), AzCopy (Azure), Transfer Service (GCP).

**Offline (physical transfer):** Ship physical devices when network transfer would take too long.

| Dataset Size | 100 Mbps Link | 1 Gbps Link | 10 Gbps Link | Physical Transfer |
|-------------|---------------|-------------|--------------|-------------------|
| 1 TB | ~1 day | ~2.5 hours | ~15 min | Overkill |
| 10 TB | ~10 days | ~1 day | ~2.5 hours | Consider |
| 100 TB | ~100 days | ~10 days | ~1 day | Recommended |
| 1 PB | ~3 years | ~100 days | ~10 days | Required |

**Rule of thumb:** If transfer would take more than 1 week over available bandwidth, consider physical transfer.

### Database Migration Patterns

- **Homogeneous** (same engine): Use native backup/restore or replication for minimal downtime.
- **Heterogeneous** (different engine): Schema conversion + DMS/CDC for data migration. Test extensively -- schema conversion is never 100% automated.
- **Cutover strategy:** Dual-write during transition, switch reads first (read replica in cloud), then switch writes. Always have rollback plan.

---

## Cross-Cloud Migration Considerations

When migrating between clouds (not just from on-prem):

- **Data transfer costs** -- Egress from source cloud is the primary cost driver. Use direct interconnects between clouds where possible.
- **Service parity** -- Map source services to target equivalents using service mapping tables. Identify gaps early.
- **Identity migration** -- Recreate IAM policies, roles, and service accounts in target cloud. Re-evaluate least privilege rather than copying 1:1.
- **DNS cutover** -- Plan carefully. Lower TTLs before migration. Have rollback plan.
- **Monitoring parity** -- Ensure monitoring, alerting, and dashboards are functional in target before cutover.
- **Compliance re-certification** -- Changing clouds may require re-certification for SOC 2, HIPAA, PCI DSS.

---

## Certification Paths by Cloud

For teams building cloud skills during/before migration:

**AWS:** Cloud Practitioner > Solutions Architect Associate > Developer/SysOps Associate > Solutions Architect Professional > Specialty (Security, Networking, Database, ML)

**Azure:** AZ-900 Fundamentals > AZ-104 Administrator / AZ-204 Developer > AZ-305 Architect Expert > AZ-400 DevOps Engineer > Specialty (AZ-500 Security, DP-300 Database)

**GCP:** Cloud Digital Leader > Associate Cloud Engineer > Professional Cloud Architect > Professional Cloud DevOps / Security / Data / ML Engineer
