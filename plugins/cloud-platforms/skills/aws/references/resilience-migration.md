# AWS Resilience and Migration Reference

> RTO/RPO, the four DR strategies with their cost trade-offs, DR tooling, the migration 7 Rs, migration phases and TCO, and the current-state tooling map. Selection level — configuration procedures belong to the owning service skills.

---

## RTO and RPO

> Source: https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/business-continuity-plan-bcp.html (official)

- **Recovery Time Objective (RTO)** — "the maximum acceptable delay between the interruption of service and restoration of service. This objective determines what is considered an acceptable time window when service is unavailable and is defined by the organization."
- **Recovery Point Objective (RPO)** — "the maximum acceptable amount of time since the last data recovery point. This objective determines what is considered an acceptable loss of data between the last recovery point and the interruption of service and is defined by the organization."

A DR strategy is a **subset of the organization's Business Continuity Plan**, not a standalone document — DR keeps the workload running; the BCP covers everything else the business needs.

Selecting objectives requires a **business impact analysis** (what does downtime cost) and a **risk assessment** (how likely is each disaster type). AWS's explicit economic rule: **"If the cost of the recovery strategy is higher than the cost of the failure or loss, the recovery option should not be put in place unless there is a secondary driver such as regulatory requirements."** For less-critical workloads, "a valid strategy may be not to have any disaster recovery in place at all" — a deliberate, sanctioned choice, not a gap.

### DR is not availability

> Source: https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/introduction.html (official)

**Disaster recovery measures objectives for one-time events (RTO/RPO); availability measures mean values over time (MTBF/MTTR).** Availability = MTBF / (MTBF + MTTR), expressed in nines, or as successful responses over valid requests for request-based workloads. DR addresses disaster-scale events; availability addresses "more common disruptions of smaller scale such as component failures, network issues, software bugs, and load spikes." Both belong in a resiliency strategy, and conflating them is the most common analysis error in this area.

---

## The Four DR Strategies

> Source: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_planning_for_recovery_disaster_recovery.html and https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html (official)

AWS presents these "in increasing order of cost and complexity, and decreasing order of RTO and RPO" — that ordering is itself the selection frame.

| Strategy | RTO | RPO | Mechanic | Cost shape |
|---|---|---|---|---|
| **Backup and restore** | 24 hours or less | Hours (point-in-time recovery can reach ~5 minutes) | Back up to the recovery Region; redeploy infrastructure and code, then restore data at failover | Lowest — storage only |
| **Pilot light** | Tens of minutes | Minutes | Core infrastructure (databases, object storage) always replicating in the recovery Region; application servers not deployed until failover | Data-layer replication plus minimal standing compute |
| **Warm standby** | Minutes | Seconds | Scaled-down but fully functional copy always running; scale up at failover | Continuous reduced-capacity footprint |
| **Multi-site active/active** | Potentially zero | Near zero | All Regions actively serve traffic; there is no failover, only Region evacuation | Full duplicate capacity |

**Pilot light versus warm standby, resolved verbatim** — the classic point of confusion: "The distinction is that pilot light cannot process requests without additional action taken first, while warm standby can handle traffic (at reduced capacity levels) immediately. Pilot light will require you to turn on servers, possibly deploy additional (non-core) infrastructure, and scale up, while warm standby only requires you to scale up (everything is already deployed and running)."

**Hot standby** is a statically stable, fully scaled warm standby that does not depend on Auto Scaling to reach production capacity. It still serves traffic from one Region at a time — that is what separates it from active/active.

**Do not over-buy:** "avoid implementing a strategy that is more stringent than it needs to be, as this incurs unnecessary costs." The realistic exercise is a maximum permissible RTO and a spending ceiling, where typically only one or two strategies satisfy both.

### Data plane versus control plane — the resilience principle behind failover design

**"For maximum resiliency, you should use only data plane operations as part of your failover operation. This is because the data planes typically have higher availability design goals than the control planes."**

Concretely: Route 53 **health-check-driven DNS failover is a data-plane operation**; **changing Route 53 weighted-routing weights is a control-plane operation** and therefore less reliable during a large event. **Amazon Application Recovery Controller (ARC)** exists to give manually triggered failover a highly available data-plane API (health checks repurposed as on/off switches). Auto Scaling scale-out during failover is also a control-plane dependency — the documented trade-off of pilot light and warm standby versus a fully pre-provisioned hot standby.

### Replication and failover primitives by strategy

- **Backup and restore** — point-in-time-capable backups via **AWS Backup** across EBS, DynamoDB, RDS/Aurora, EFS, Redshift, Neptune, DocumentDB, and FSx, with **cross-Region and cross-account copy**. The cross-account capability specifically protects against "disaster events that include insider threats or account compromise." Note: **AWS Backup does not currently support scheduled or automatic restoration** — build that yourself if you want restore-to-DR-Region automation.
- **Pilot light** — continuous asynchronous cross-Region replication: S3 Replication, RDS read replicas, **Aurora Global Database**, DynamoDB global tables, DocumentDB global clusters, ElastiCache (Redis OSS) Global Datastore. Aurora Global Database promotes a secondary Region to read/write **"in less than one minute"** even after a complete regional outage, with typical replication latency **"under a second."**
- **Warm standby** — adds EC2 Auto Scaling to reach production capacity at failover; explicitly a control-plane dependency versus paying for hot standby.
- **Multi-site active/active** — no failover concept; testing validates **Region evacuation**. Write-consistency patterns: **write global** (all writes to one Region — Aurora Global Database, which supports write forwarding from secondaries), **write local** (writes to the nearest Region — DynamoDB global tables, last-writer-wins), **write partitioned** (writes sharded by key — bidirectional S3 replication, with replica modification sync enabled so ACL/tag/lock changes replicate too).

Traffic-routing options at failover: **Route 53** health-check DNS failover (or ARC for manual data-plane control), **AWS Global Accelerator** (anycast IPs plus health checks, avoiding DNS caching delay and using the AWS backbone), and **CloudFront origin failover** — which is per-request, not sticky, so only the failed request retries against the secondary origin.

### AWS Elastic Disaster Recovery (DRS)

> Source: https://docs.aws.amazon.com/drs/latest/userguide/what-is-drs.html (official)

DRS "minimizes downtime and data loss with fast, reliable recovery of on-premises and cloud-based applications using affordable storage, minimal compute, and point-in-time recovery." It continuously replicates server-hosted applications and databases from any source (on-premises, another cloud, or EC2-hosted workloads — not RDS) using **block-level replication** into a staging-area VPC on low-cost storage and minimal compute.

**Architecturally it implements pilot light, but with better objectives.** Well-Architected, verbatim: **"When cost is a concern, and you wish to achieve a similar RPO and RTO objectives as defined in the warm standby strategy, you could consider cloud native solutions, like AWS Elastic Disaster Recovery, that take the pilot light approach and offer improved RPO and RTO targets."** In practice: **RPO in seconds, RTO in minutes, at pilot-light-class standing cost.**

On failover or drill it automatically converts replicated servers to boot natively on AWS, supports **non-disruptive recovery and failback drills**, and supports **failback** to the original source.

### AWS Backup's role

"AWS Backup is a fully managed service that centralizes and automates data protection across AWS services and hybrid workloads," including VMware and Storage Gateway volumes, with cross-Region and cross-account copy, automatic restore testing and validation, and immutable backups for ransomware resilience.

**Selection distinction to carry:** AWS Backup is **scheduled, centrally managed point-in-time backup and restore** — the data layer of the backup-and-restore strategy. DRS is **continuous block-level replication with orchestrated compute failover** — the pilot-light-improved strategy. They are complementary: the DR whitepaper recommends point-in-time backups of the *replicated* data in pilot light and warm standby too, because continuous replication faithfully replicates corruption and deletion to the DR side.

---

## Resilience Primitives

### AZ scope versus Region scope — get this right first

**"Availability Zones within an AWS Region are already designed with meaningful distance between them, and careful planning of location, such that most common disasters should only impact one zone and not the others. Therefore, a multi-AZ architecture within an AWS Region may already meet much of your risk mitigation needs."**

Escalate to a multi-Region DR strategy only when the disaster definition extends to loss of an entire Region, or when regulation requires it. **Data-residency requirements can rule out multi-Region DR entirely** — if compliance scope permits only one Region, Multi-AZ is the ceiling, not a stepping stone.

A single-Region multi-AZ deployment blends the vocabulary: an ALB plus EC2 fleet across AZs is active/active-style; an RDS Multi-AZ standby promoted on AZ failure is hot-standby-style. The reuse of terms across scope levels is the most common source of confusion.

### Route 53 failover types

> Source: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover-types.html (official)

- **Active-active failover** uses **any routing policy other than Failover** (weighted, latency-based, etc.) combined with health checks — "all the records that have the same name, type, and routing policy... are active unless Route 53 considers them unhealthy."
- **Active-passive failover** uses the **Failover routing policy** specifically, with a designated Primary and Secondary. This is the DNS mechanism behind pilot-light and warm-standby Region failover.

Both rely on Route 53 health checks — a **data-plane** operation, which is why they are more resilient than manually repointing weights.

### RDS Multi-AZ versus cross-Region replicas

> Source: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html (official)

- **Multi-AZ DB instance** — one standby, **synchronous** replication, automatic failover, **standby serves no read traffic**. Single-Region HA, not DR.
- **Multi-AZ DB cluster** — two standbys across three AZs, **standbys can serve reads**, still single-Region.
- **Cross-Region read replicas** — asynchronous; "you must promote an RDS read replica to become the primary instance," and for non-Aurora engines that "takes a few minutes to complete and rebooting is part of the process."
- **Aurora Global Database** — the preferred Aurora cross-Region primitive: dedicated replication infrastructure, sub-second typical latency, promotion in under a minute, and RPO-lag monitoring against a target.

**The rule: Multi-AZ is HA within a Region and does not satisfy a cross-Region RTO/RPO requirement.** Cross-Region read replicas and Aurora Global Database are the DR primitives.

### S3 replication

> Source: https://aws.amazon.com/s3/features/replication/ (official)

**Cross-Region Replication (CRR)** replicates objects with their metadata and tags into other Regions, configurable at bucket, prefix, or object-tag level. **Same-Region Replication (SRR)** exists for log aggregation and account-boundary copies. **S3 Replication Time Control (RTC)** is the SLA-backed tier: **99.99% of new objects replicated within 15 minutes** — the figure to cite when a scenario needs a bounded S3 RPO. Plain CRR is asynchronous best-effort, usually much faster but with no SLA.

**Pair CRR with S3 Object Versioning.** CRR gives "the shortest time (near zero) to back up your data, but may not protect against disaster events such as data corruption or malicious attack (such as unauthorized data deletion) as well as point-in-time backups." With versioning, a delete in the source only adds a delete marker there — and **delete markers are not replicated by default**, which is what protects the DR copy from an accidental or malicious delete in the primary Region.

### Testing and failback

> Source: https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/testing-disaster-recovery.html (official)

**"Our experience has shown that the only error recovery that works is the path you test frequently."** Untested failover paths fail under real load on stale assumptions about capacity and service quotas. Keep the number of distinct recovery paths small and exercise them regularly, including in production for critical paths.

Watch for **configuration drift** in the DR Region — stale AMIs, insufficient service quotas. AWS Config detects drift and can trigger Systems Manager Automation to remediate; CloudFormation detects stack-level drift. **AWS Resilience Hub** continuously validates whether an architecture is likely to meet its configured RTO/RPO targets.

**Failback** follows the same IaC path as the original DR deployment; the hard part is data resynchronization. DynamoDB global tables and Aurora Global Database (with managed planned failover) resynchronize automatically once the former primary returns; for other engines you typically re-establish the old primary as a replica of the now-live recovery Region. Some organizations run **scheduled Region rotation** (swapping primary and recovery every few months) to keep failback muscle memory current. DRS orchestrates failback specifically.

---

## Migration Strategy: The 7 Rs

> Source: https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-migration/migration-strategies.html (official)

"There are seven migration strategies for moving applications to the cloud, known as the 7 Rs."

| Strategy | Also called | Definition | When it applies |
|---|---|---|---|
| **Retire** | -- | Decommission or archive; shut down the servers | No business value in moving it; **"zombie applications"** (average CPU and memory under 5% over 90 days) or **"idle applications"** (5-20% over 90 days); no inbound connections in 90 days |
| **Retain** | -- | Leave it in the source environment for now | Data residency; high-risk apps needing assessment; migration-order dependencies; recently upgraded; pending SaaS version; physical-hardware dependencies; **mainframe/mid-range/non-x86 Unix** needing careful assessment |
| **Rehost** | "Lift and shift" | Move with **no changes** | Large server counts, no compatibility or performance re-engineering, short cutover; optimize after arrival. Automated by **AWS Transform MGN**, Cloud Migration Factory, VM Import/Export |
| **Relocate** | -- | Transfer to a cloud version of the same platform, or move instances/objects between VPCs, Regions, or accounts | "the quickest way to migrate and operate your workload in the cloud because it does not impact the overall architecture of your application" |
| **Repurchase** | "Drop and shop" | Replace with a different product, usually SaaS | Moving off traditional licensing; version upgrades; replacing a custom app to avoid recoding. Post-purchase work: training, data migration, auth integration, network security |
| **Replatform** | "Lift, tinker, and shift" | Move with **some optimization** | SQL Server to RDS for SQL Server; OS upgrade for compliance; **Graviton** for cost; Windows to Linux via .NET Framework to .NET Core (Porting Assistant for .NET); VMs to containers via App2Container |
| **Refactor** | "Re-architect" | Move **and** redesign for cloud-native | Legacy mainframe that cannot meet demand; a monolith blocking delivery; unmaintainable code; table-level extraction for compliance (separating PII to retain on-premises) |

### The sequencing rule that decides most large-migration questions

Verbatim: **"Common strategies for large migrations include rehost, replatform, relocate, and retire. Refactor is not recommended for large migrations because it involves modernizing the application during the migration... Instead, we recommend rehosting, relocating, or replatforming the application and then modernizing the application after the migration is complete."**

Restated: **"For a large migration, refactor only when the other migration strategies are not an acceptable option. In large migrations, whenever possible, we recommend that you modernize applications after the migration is complete."**

Migrate first, modernize second.

---

## Migration Phases and the Business Case

> Source: https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-migration/overview.html, .../assess-phase.html, https://docs.aws.amazon.com/prescriptive-guidance/latest/large-migration-guide/phases.html (official)

1. **Assess** — build the business case and TCO analysis; run a **Migration Readiness Assessment** against the **AWS Cloud Adoption Framework**'s six perspectives (business, people, governance, platform, security, operations). Outputs: where the enterprise is in its cloud journey, strengths and weaknesses versus a cloud-ready enterprise, and "an action plan to close identified gaps."
2. **Mobilize** — build the landing zone, migrate a small first wave, establish the cloud operating model, prove out security and operations automation. Eight workstreams across eight two-week sprints: detailed business case, portfolio discovery, application migration, migration governance, landing zone, security/risk/compliance, operations, and people.
3. **Migrate and modernize** — apply the proven patterns at scale through a **migration factory**: "a blueprint of scaling implementation and operations, through automation and agile delivery."

**Migration-factory mechanics:** Stage 1 *Initialize* (1-3 months — platform and people readiness, standard-operating-procedure **runbooks**) then Stage 2 *Implement* (migrate at scale in batches called **waves**). Four workstreams: **Foundation**, **Project governance**, **Portfolio** (collects migration metadata, prioritizes applications, **performs wave planning**), and **Migration** (executes cutover per the wave plan).

### TCO with Migration Evaluator

> Source: https://docs.aws.amazon.com/prescriptive-guidance/latest/migration-tools/business-case-migration-evaluator.html and https://aws.amazon.com/migration-evaluator/ (official)

Migration Evaluator exists to **"Build a data-driven business case for AWS."** It is **free**, deployed as SaaS, and collects data via an **Agentless Collector** or an upload of existing inventory (CMDB, vCenter, SolarWinds, SCCM).

Right-sizing maps source vCPU/RAM/disk plus a utilization time series (peak, average, standard deviation, percentile — minimum one month of 5-minute samples) to an optimal EC2 instance type, including tenancy and burstable-instance exclusion.

**TCO coverage:** on-premises server, storage, software/license/support, and facility costs (rack, power, real estate) over 1- and 3-year horizons; AWS-side EC2/RI, storage, database, VMware Cloud on AWS, and license costs. License modeling covers BYOL versus license-included, core-count optimization, and database consolidation.

**It explicitly does not cover migration-execution costs** — the cost of running the migration project itself is a separate line item you must budget outside the tool's output.

---

## Migration Tooling Map — with current-state currency

> Source: https://aws.amazon.com/transform/, https://docs.aws.amazon.com/migrationhub/latest/ug/document-history.html, https://docs.aws.amazon.com/application-discovery/latest/userguide/what-is-appdiscovery.html, https://docs.aws.amazon.com/snowball/latest/developer-guide/snowball-edge-availability-change.html, https://docs.aws.amazon.com/mgn/latest/ug/what-is-application-migration-service.html (official)

**Read this before recommending any tool below.** AWS has consolidated much of this surface under **AWS Transform**, and several long-standing services still named in current certification guides are closed to new customers. **Teach both facts with their dates:** the exam vocabulary a candidate must know, and the tool a 2026 project would actually provision.

**AWS Transform** is the umbrella entry point: "a collaborative enterprise IT transformation workbench powered by expert agents that accelerates cloud migration, application modernization, and continuous tech debt reduction," spanning infrastructure migration (VMware, bare metal, hybrid), application modernization (mainframe, Windows/.NET, custom code), and continuous tech-debt remediation. It automates discovery, wave planning, network setup, landing-zone creation, rehosting, and containerization as an agentic workflow. Individual services below still have their own consoles and documentation — Transform orchestrates them rather than fully replacing them.

### Discovery and assessment

| Tool | Current status | Role |
|---|---|---|
| **AWS Migration Hub** | **Closed to new customers as of November 7, 2025.** Verbatim: "AWS Migration Hub is no longer open to new customers as of November 7, 2025. For capabilities similar to AWS Migration Hub, explore AWS Transform." | Single console aggregating discovery and migration-tracking status; **home Region** concept holds a portfolio's planning data |
| **AWS Application Discovery Service (ADS)** | **Closed to new customers.** Verbatim: "AWS Application Discovery Service is no longer open to new customers. Alternatively, use AWS Transform which provides similar capabilities." | Collects on-premises server and database usage and configuration to feed Migration Hub, Migration Evaluator, and TCO modeling |
| **AWS Migration Evaluator** | **Open, no charge** — not affected by the closures above | Business case and TCO |
| **AWS Transform** | Current | Portfolio assessment plus infrastructure discovery — the practical replacement path |

ADS's three discovery methods, still documented for existing customers: the **Agentless Collector** (OVA appliance via vCenter — static configuration plus utilization averages and peaks, roughly 60-minute intervals, no in-VM process or connection visibility), the **Discovery Agent** (per-server, adds detailed time-series performance, network connections, and running processes at ~15-second intervals), and **file-based import / RVTools export** for a one-time snapshot.

### Database migration — DMS and schema conversion

> Source: https://docs.aws.amazon.com/dms/latest/userguide/data-migrations.html (official)

- **Homogeneous migration** (same engine both sides — on-premises PostgreSQL to RDS or Aurora PostgreSQL): DMS uses **native database tools** for a like-to-like move. This mode is **serverless** — DMS manages compute and storage — and migrates rows, table partitions, and secondary objects (functions, stored procedures). Supported sources: SQL Server, Oracle, PostgreSQL, MySQL, IBM DB2 for z/OS, SAP ASE; source on-premises, EC2, or RDS; target RDS or Aurora. Three run modes: full load, ongoing replication, or both.
- **Heterogeneous migration** (different engines — Oracle to Aurora PostgreSQL) requires **schema conversion first**, then DMS for the data.
- **Currency note:** **DMS Schema Conversion** is now a console-based capability inside AWS DMS, replacing the workflow that required downloading the standalone **AWS Schema Conversion Tool (SCT)** desktop application. **Selection rule: homogeneous -> DMS alone; heterogeneous -> DMS plus schema conversion** (DMS Schema Conversion in-console, or the legacy standalone SCT where DMS SC does not cover the source/target pair).

### Bulk data transfer — and the Snow Family wind-down

- **AWS DataSync** — online data movement with encryption in transit and end-to-end integrity validation. Four use cases: migration of large datasets, ongoing replication into S3/EFS/FSx, direct archival to S3 Glacier, and hybrid/multicloud transfer. Sources include NFS, SMB, HDFS, and self-managed S3-API object storage; destinations include S3, EFS, and the FSx family, preserving permissions and metadata.
- **AWS Snow Family — do not describe this as the classic three-tier family any more:**
  - **Snowmobile** — retired.
  - **Snowcone** — **discontinued November 12, 2024**; existing-customer support ended November 12, 2025.
  - **Snowball Edge** — **no longer available to new customers as of November 7, 2025.** Verbatim: "New customers should explore AWS DataSync for online transfers, AWS Data Transfer Terminal for secure physical transfers, or AWS Partner solutions. For edge computing, explore AWS Outposts."
  - **Full commercial-Region discontinuation is dated: "On December 31, 2026, AWS will discontinue support for AWS Snowball devices in all AWS commercial Regions."** GovCloud and ADC Region customers with active jobs are unaffected.

**Implication for advice:** the classic answer "use Snowball Edge when bandwidth is insufficient" is now a **historical pattern**. Current alternatives are **DataSync** (online, optionally paired with a temporary Direct Connect hosted connection to overcome bandwidth limits), **AWS Data Transfer Terminal** (a physical facility where customers bring their own storage devices for fast upload), and **AWS Outposts** for the edge-compute cases Snowball Edge Compute Optimized served.

### Server migration — MGN

> Source: https://docs.aws.amazon.com/mgn/latest/ug/what-is-application-migration-service.html and https://docs.aws.amazon.com/mgn/latest/ug/General-Questions-FAQ.html (official)

**Currency note:** AWS Application Migration Service now displays in its own documentation as **"AWS Transform MGN."** Verbatim: "AWS Application Migration Service has been renamed to AWS Transform MGN. The new name reflects the close link between MGN and AWS Transform. AWS Transform uses MGN replication technology to rehost servers." Same service, same replication engine.

It automates migration of physical, virtual, and cloud servers with **cutover windows typically measured in minutes**, via **continuous block-level replication** and automatic conversion for AWS launch, across a broad OS range, with IPv4/IPv6 and standard AZ or Local Zone targets. It organizes servers into **applications** and applications into **waves**, with bulk configure/launch/cutover/archive actions at each level — this is the execution engine for the rehost strategy.

**MGN versus DRS, verbatim:** "DRS can be used for migration, as the DRS and MGN services use shared technology for performing block level replication. Both MGN and DRS have a replication agent, for replicating servers into a staging area in AWS. MGN supports launching test and cutover instances from the staging area. DRS supports launching recovery instances from the staging area... **DRS also has the capability to failback to the source environment... This capability does not exist in MGN.**"

Practical rules: **do not run both agents on the same source server** — uninstall one before installing the other. Choose DRS over MGN for a migration when you need a DRS-only feature such as failback, or when the workload is really an ongoing DR posture rather than a one-time cutover.

---

## Target-Platform Selection for a Migrating Workload

Migration questions are usually platform-selection questions wearing a migration costume. Map the source to a target using the decision trees in `SKILL.md` and the depth references, filtered through the chosen R:

| Source shape | Rehost target | Replatform target | Refactor target |
|---|---|---|---|
| Windows/Linux VM fleet | EC2 via AWS Transform MGN, same instance shape | Graviton-based EC2, or Windows to Linux with .NET Core (Porting Assistant for .NET) | ECS/EKS/Fargate, or Lambda for event-driven components |
| Self-managed database on VMs | EC2-hosted database (rarely the right answer for long) | **RDS or Aurora** for the same engine (homogeneous, DMS alone) | Purpose-built engine — DynamoDB, Aurora Serverless v2, OpenSearch — with heterogeneous DMS plus schema conversion |
| On-premises NAS or file server | EC2 plus EBS | **FSx for Windows File Server** (SMB) or **EFS** (Linux NFS); FSx for NetApp ONTAP where ONTAP features are load-bearing | S3 plus an application rewrite to object semantics |
| Monolithic application server | EC2 with an ALB | Containerize with **App2Container** onto ECS or EKS | Decompose into services behind API Gateway, SQS/SNS/EventBridge, and purpose-built datastores |
| On-premises Hadoop or ETL cluster | EC2-hosted cluster | **EMR** on EC2, or **EMR Serverless** | S3 data lake plus Glue and Athena — see `references/analytics.md` |
| On-premises analytics warehouse | EC2-hosted warehouse | **Redshift** provisioned | **Redshift Serverless**, or a lakehouse composition over S3 |

Two constraints to apply to every row: the **"migrate first, modernize second"** sequencing rule above, and the operating reality that **licensing and data-gravity usually dominate the choice** — Migration Evaluator's license modeling and the data-transfer approach (DataSync versus Data Transfer Terminal) frequently decide the target before technical fit does.

## Sources

- https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/business-continuity-plan-bcp.html
- https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/introduction.html
- https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html
- https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/testing-disaster-recovery.html
- https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_planning_for_recovery_disaster_recovery.html
- https://docs.aws.amazon.com/drs/latest/userguide/what-is-drs.html
- https://aws.amazon.com/backup/
- https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover-types.html
- https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html
- https://aws.amazon.com/s3/features/replication/
- https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-migration/migration-strategies.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-migration/overview.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-migration/assess-phase.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/large-migration-guide/phases.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/migration-tools/business-case-migration-evaluator.html
- https://aws.amazon.com/migration-evaluator/
- https://aws.amazon.com/transform/
- https://docs.aws.amazon.com/migrationhub/latest/ug/document-history.html
- https://docs.aws.amazon.com/application-discovery/latest/userguide/what-is-appdiscovery.html
- https://docs.aws.amazon.com/dms/latest/userguide/data-migrations.html
- https://docs.aws.amazon.com/dms/latest/userguide/dm-data-providers-source.html
- https://aws.amazon.com/datasync/
- https://aws.amazon.com/snowball/
- https://docs.aws.amazon.com/snowball/latest/developer-guide/snowball-edge-availability-change.html
- https://docs.aws.amazon.com/mgn/latest/ug/what-is-application-migration-service.html
- https://docs.aws.amazon.com/mgn/latest/ug/General-Questions-FAQ.html

Fetched: 2026-08-08
