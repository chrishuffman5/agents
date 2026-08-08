---
name: aws
description: "AWS platform architecture and strategy: service selection across compute, storage, database, networking, security, serverless, messaging, and analytics (EC2, S3, Lambda, RDS, Aurora, DynamoDB, EKS, ECS, VPC, IAM, CloudFront, SQS/SNS/EventBridge, Athena/Glue/Kinesis), plus multi-account governance, tagging strategy, DR and migration planning, with pricing context and trade-offs. Use when choosing between AWS services, designing a landing zone, sizing an AWS architecture, or optimizing AWS spend -- \"AWS\", \"EC2 vs Lambda\", \"which AWS database\", \"S3 storage class\", \"Savings Plans\", \"Fargate\", \"NAT Gateway costs\", \"ALB vs NLB\", \"AWS Organizations\", \"Control Tower\", \"landing zone\", \"multi-account\", \"tagging strategy\", \"tag policy\", \"disaster recovery\", \"migration to AWS\". Do NOT use for CLI syntax (`cli-scripting`), CloudFormation/Terraform authoring (`devops`), EKS ops (`containers`), DB engine tuning (`database`), VPC/TGW depth (`aws-vpc` in `networking`), S3 depth (`aws-s3` in `storage`), IAM depth (`aws-iam` in `security`), or EC2 instance sizing/images/host ops (the `cloud-vms` skill in `virtualization`)."
license: MIT
---

# AWS Technology Expert

Architecture and strategy for Amazon Web Services. Every recommendation resolves the tradeoff triangle: **performance**, **cost**, **operational complexity**.

Prices are US East (N. Virginia) on-demand, verified against AWS pricing pages on 2026-08-08. AWS changes prices frequently — treat every dollar figure as an order-of-magnitude anchor and re-check https://aws.amazon.com/pricing/ before committing a number to a customer document.

## Request Routing

Classify the request, then load only the reference(s) you need. Do not load all of them.

| Request type | Load |
|---|---|
| EC2 family/generation, Lambda vs containers, ECS vs EKS, Fargate sizing, Auto Scaling, right-sizing, edge/hybrid compute | `references/compute.md` |
| S3 classes and lifecycle, EBS volume types, EFS vs FSx, S3 Tables | `references/storage.md` |
| RDS vs Aurora, DynamoDB capacity, ElastiCache/MemoryDB/Valkey, time-series, RDS Proxy | `references/database.md` |
| NAT/endpoint cost, TGW vs peering vs PrivateLink, DX vs VPN, hybrid DNS, CloudFront, Route 53, ELB | `references/networking.md` |
| IAM policy mechanics, KMS, Secrets Manager, GuardDuty/Security Hub/Config/WAF cost and rule strategy | `references/security.md` |
| Org-wide security posture: SRA account layout, org-wide detection services, account data-protection defaults | `references/security-platform.md` |
| Multi-account design: Organizations, OU taxonomy, SCPs/RCPs, Control Tower, delegated admin, Identity Center | `references/multi-account.md` |
| Tagging strategy, tag policies, tag enforcement, cost allocation tags, org-wide inventory | `references/tagging-governance.md` |
| RTO/RPO, DR strategy selection, migration 7 Rs, migration tooling and its currency | `references/resilience-migration.md` |
| Athena/Glue/Lake Formation/EMR/Kinesis/MSK/Quick/OpenSearch, data-lake pattern | `references/analytics.md` |
| Deployment strategy (blue/green, canary), observability/SLOs, Systems Manager config management | `references/operations.md` |
| Lambda patterns, API Gateway, Step Functions, EventBridge | `references/serverless.md` |
| SQS vs SNS vs EventBridge vs Kinesis selection | `references/messaging.md` |
| Cost review, Savings Plans vs RIs, cost traps, estimation templates | `references/cost.md` |

Route out of this skill entirely when the request is CLI mechanics (`aws-cli` in `cli-scripting`), IaC authoring (`devops`), EKS day-2 operations (`containers`), engine-level tuning (`database`), or VPC/S3/IAM/EC2 depth (`aws-vpc`, `aws-s3`, `aws-iam`, `cloud-vms`).

## How to Approach Tasks

1. **Name the cost model, always.** Never recommend a service without stating how it bills and what the cheaper alternative would be. Give a concrete monthly estimate where the inputs allow one.
2. **Match the purchasing model to the demand shape.** On-Demand while unknown, Savings Plans for steady state, Spot for interruption-tolerant, serverless for spiky.
3. **Default to Graviton.** Recommend ARM instances unless there is a hard x86 or Windows dependency.
4. **Default to Identity Center, never IAM users, for human access.** Same stance as the `aws-cli` skill in `cli-scripting`.
5. **Default to tag-on-create.** Tags applied after the fact leave an untagged window and are unenforceable; see `references/tagging-governance.md`.
6. **Challenge the ask.** Confirm the user needs the service they named before sizing it.
7. **Say when a figure is volatile.** Distinguish billing *model* (stable, safe to assert) from billing *rate* (volatile, verify).

## Compute Decision Tree

> Source: https://aws.amazon.com/eks/pricing/ and https://aws.amazon.com/about-aws/whats-new/2024/12/amazon-eks-auto-mode/ (official)

```
Short-lived, event-driven task (< 15 min)?
  YES -> Needs > 10 GB memory or a GPU?
    YES -> ECS/EKS on EC2 (GPU instances) or EC2 directly
    NO  -> Lambda (start here; move to containers if sustained cost exceeds it)
  NO -> Long-running service?
    YES -> Need the K8s ecosystem / multi-cloud portability?
      YES -> Want K8s without cluster ops? -> EKS Auto Mode (AWS provisions and
             patches compute, storage, networking; K8s 1.29+, no extra control-plane fee)
          -> Otherwise EKS ($0.10/cluster-hour Standard Support, ~$73/mo)
      NO  -> ECS (free control plane)
        -> Fargate vs EC2? see references/compute.md
    NO -> Batch job? -> AWS Batch on Spot
       -> Otherwise EC2 with Auto Scaling
```

**EKS version-lag cost trap:** clusters left on a Kubernetes version past the 14-month standard window move to Extended Support at **$0.60/cluster-hour** (~6x standard), up to 26 months total. Budget the upgrade, not the surcharge.

## Database Decision Tree

> Source: https://docs.aws.amazon.com/timestream/latest/developerguide/timestream-availability-update.html and https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-console-comparison.html (official)

```
Structured data + complex queries + transactions?  -> RDS or Aurora
Key-value at scale, single-digit ms?               -> DynamoDB
Caching / session store / real-time structures?    -> ElastiCache (Valkey, Redis OSS, Memcached)
Durable in-memory primary datastore?               -> MemoryDB (Valkey or Redis OSS)
MongoDB-compatible documents?                      -> DocumentDB
Graph traversal?                                   -> Neptune
Time-series?                                       -> Timestream for InfluxDB
                                                      (LiveAnalytics is legacy; AWS steers
                                                       migrations to InfluxDB 3 Enterprise)
Full-text search + log analytics?                  -> OpenSearch Service
Data warehouse?                                    -> Redshift Serverless by default
                                                      (per-second RPU billing, no pause/resume,
                                                       no maintenance window); provisioned only
                                                       for steady 24/7 usage that can commit to RIs
```

**Valkey first for new cache deployments.** ElastiCache supports Valkey, Memcached, and Redis OSS. Per AWS's pricing page, ElastiCache Serverless for Valkey is priced ~33% below Serverless for Redis OSS/Memcached and node-based Valkey ~20% below node-based Redis OSS, with a 100 MB serverless minimum vs 1 GB. Choose Redis OSS only for a hard Redis-specific dependency. Detail in `references/database.md`.

## Storage Decision Tree

> Source: https://aws.amazon.com/s3/storage-classes/ and https://aws.amazon.com/ebs/volume-types/ (official)

```
Objects, images, video, backups?      -> S3 (pick class by access pattern)
Analytics tables (Iceberg)?           -> S3 Tables (Iceberg-native, queryable by Athena/Redshift/Spark)
Shared POSIX filesystem?
  Linux   -> EFS (elastic, three classes: Standard/IA/Archive) or FSx for Lustre (HPC/ML)
  Windows -> FSx for Windows File Server
  Multi-protocol / enterprise NAS -> FSx for NetApp ONTAP or FSx for OpenZFS
Block storage attached to an instance -> EBS gp3 (never gp2)
```

## Top Cost Optimization Rules

> Source: https://aws.amazon.com/ec2/instance-types/graviton/, https://aws.amazon.com/savingsplans/compute-pricing/, https://aws.amazon.com/compute-optimizer/pricing/, https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-allocation-strategies.html, https://aws.amazon.com/vpc/pricing/ (official)

1. **Graviton by default.** AWS states up to 20% lower cost versus comparable x86, with up to 30-40% better performance on compute-bound workloads and up to 60% less energy. Baseline on Graviton4 (`8g`: M8g/C8g/R8g); Graviton5 (`9g`) is the new frontier — M9g/M9gd GA June 2026.
2. **gp3 over gp2, always.** gp3 includes 3,000 IOPS and 125 MBps at a lower per-GB rate and scales to 80,000 IOPS / 2,000 MBps; gp2 is tied to 3 IOPS/GB.
3. **Create S3 and DynamoDB Gateway Endpoints.** They carry no hourly or data-processing charge and remove that traffic from NAT Gateway billing.
4. **Lifecycle every bucket.** Standard -> Standard-IA (30d) -> Glacier Flexible (90d) -> Deep Archive (365d) is the canonical ladder; savings compound to roughly 85-90% for cold data.
5. **Compute Savings Plans for steady state.** Up to 66% (3-year all-upfront), covering EC2 across family/size/AZ/Region/OS/tenancy plus Fargate and Lambda.
6. **Right-size quarterly with Compute Optimizer.** Basic recommendations are free over a 14-day lookback; the paid enhanced tier ($0.0003360215/resource-hour) extends the lookback to about three months and now covers EC2, ASGs, Lambda, EBS, ECS on Fargate, RDS/Aurora, NAT Gateway, DynamoDB, ElastiCache, MemoryDB, DocumentDB, WorkSpaces, SageMaker, and licenses.
7. **Stop dev/test out of hours.** AWS's own cost pillar cites ~75% savings for a 40-hour-vs-168-hour week.
8. **Move steady DynamoDB tables off On-Demand.** Provisioned + Auto Scaling is materially cheaper at sustained throughput — but size the claim against post-November-2024 on-demand rates, not the old ones (see `references/cost.md`).
9. **Watch NAT Gateway.** $0.045/hour ($32.85/month) plus $0.045/GB processed; three AZs is $98.55/month before a byte moves.
10. **Spot for interruption-tolerant work.** Up to 90% off. Diversify across 6+ instance types and all AZs; use `price-capacity-optimized` (AWS's balanced modern default) or `capacity-optimized`.

## Common Pitfalls

> Source: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.StorageReliability.html, https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/, https://aws.amazon.com/about-aws/whats-new/2024/11/amazon-dynamo-db-reduces-prices-on-demand-throughput-global-tables (official)

1. **No Gateway Endpoints for S3/DynamoDB.** They are free. Every VPC should have both.
2. **gp2 volumes still running.** Migrate to gp3 — online, no downtime.
3. **Lambda left on x86.** `arm64` is cheaper and usually faster; switch unless a native x86 dependency blocks it.
4. **Aurora Standard mode with heavy I/O.** AWS's own rule: "Aurora I/O-Optimized is the best choice when your I/O spending is 25% or more of your total Aurora database spending." Switching is allowed once per 30 days; zero-downtime for non-NVMe instances (including all Serverless), restart required for NVMe-backed provisioned instances.
5. **DynamoDB On-Demand at sustained throughput.** Still a real trap, but AWS cut on-demand throughput prices ~50% effective November 1, 2024 — the gap versus right-sized Provisioned is now roughly 70%, not the ~85% older material claims.
6. **Over-provisioned NAT in non-production.** Production wants one per AZ; dev/staging can share one, or use a NAT instance.
7. **Unattached EBS volumes and idle public IPv4.** Every public IPv4 address bills $0.005/hour (~$3.60/month) whether attached or not, since February 1, 2024.
8. **CloudWatch Logs with no retention policy.** Default is never-expire at $0.50/GB ingested.
9. **Dev/test caches sized for production.** Use a `t4g` node class or ElastiCache Serverless.
10. **One ALB per service.** Consolidate with host-based routing (up to 100 rules per listener).
11. **A tag policy assumed to make tags mandatory.** It does not — see the tagging note below.
12. **Workloads in the Organizations management account.** SCPs do not restrict it, so nothing there is under your guardrails.

## Key Architecture Decisions

### Savings Plans vs Reserved Instances

> Source: https://aws.amazon.com/savingsplans/compute-pricing/ and https://aws.amazon.com/ec2/pricing/reserved-instances/ (official)

| Feature | Savings Plans | Reserved Instances |
|---|---|---|
| Flexibility | Compute SP: any family/size/AZ/Region/OS/tenancy. EC2 Instance SP: family + Region | Locked to type + Region (Convertible RIs allow family change) |
| Services | EC2, Fargate, Lambda (plus separate SageMaker AI Savings Plans) | EC2, RDS, ElastiCache, OpenSearch, Redshift |
| Max discount | Compute SP up to 66%; EC2 Instance SP up to 72% | Standard RI up to 72%; Convertible RI up to 66% |
| Use | **Default for EC2/Fargate/Lambda** | **Required for RDS/ElastiCache/OpenSearch/Redshift** (no SP option) |

### ECS vs EKS

> Source: https://aws.amazon.com/eks/pricing/ (official)

| Factor | ECS | EKS |
|---|---|---|
| Control plane | Free | $0.10/hour Standard (~$73/mo); $0.60/hour Extended Support |
| Learning curve | Low (AWS concepts) | Steeper (Kubernetes) |
| Operational burden | Low | Medium — or Low with **EKS Auto Mode** |
| Portability | AWS-locked | Multi-cloud |
| Ecosystem | AWS-native | Istio, ArgoCD, Karpenter, KEDA |

Choose ECS for AWS-native teams wanting the smallest operational surface. Choose EKS for existing Kubernetes investment or ecosystem needs; Auto Mode closes most of the historic ops-burden gap.

### Aurora vs RDS

> Source: https://aws.amazon.com/rds/features/read-replicas/ and https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.StorageReliability.html (official)

| Factor | Aurora | RDS |
|---|---|---|
| Multi-AZ | Included (6-way replication across 3 AZs) | Standby instance roughly doubles compute cost |
| Read replicas | Up to 15, storage-layer replication, <10 ms lag | Up to **15** for MySQL/PostgreSQL/MariaDB/SQL Server (Oracle: 5), engine-native async replication with higher, more variable lag |
| Storage | Auto-scales to **256 TiB** | Pre-provisioned |
| Best for | Production HA and read-heavy workloads | Small/dev, budget-constrained, or engine versions Aurora lacks |

**Replica count is no longer an Aurora differentiator** for the common engines — argue Aurora on replication *lag and architecture*, on included Multi-AZ durability, and on Global Database, not on the number 15.

### Load Balancer Selection

> Source: https://aws.amazon.com/elasticloadbalancing/pricing/ (official)

```
HTTP/HTTPS traffic?
  YES -> Need static IPs? -> NLB -> ALB chained, or ALB + Global Accelerator
                          -> Otherwise ALB (path/host routing, Lambda targets, gRPC)
  NO  -> TCP/UDP/TLS? -> NLB (millions of connections, ultra-low latency, PrivateLink provider)
      -> Inline third-party security appliance? -> Gateway Load Balancer
```

### Encryption Decision

> Source: https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-encryption-faq.html and https://docs.aws.amazon.com/ebs/latest/userguide/encryption-by-default.html (official)

```
At rest:
  S3        -> SSE-S3 is the floor on every bucket since January 5, 2023 and cannot be disabled.
               Upgrade to SSE-KMS with a customer-managed key when you need an independently
               revocable second control and per-request audit. Enable S3 Bucket Keys with SSE-KMS.
  EBS       -> Turn on encryption-by-default per Region; it is forward-only and cannot be
               bypassed per-volume once set.
  RDS       -> Enable at creation; it cannot be added to an existing instance in place.
  DynamoDB  -> Encrypted by default with an AWS-owned key; move to a CMK for key control.
  Secrets   -> Secrets Manager when rotation is required; Parameter Store SecureString otherwise.

In transit:
  Internet-facing -> TLS 1.2+ via an ACM certificate on ALB/CloudFront/API Gateway
  Inside the VPC  -> VPC endpoints / PrivateLink
  Database        -> force SSL at the parameter level and validate the CA certificate
```

## Multi-Account Baseline

> Source: https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/recommended-ous-and-accounts.html and https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/account-structure.html (official)

AWS's recommended top-level OU set, with the accounts each holds:

- **Security OU** — **Log Archive** (immutable central log store) and **Security Tooling / Audit** (delegated admin for the detection services). Keep this OU to exactly those; put other security-adjacent accounts in a sibling OU.
- **Infrastructure OU** — Network, Shared Services, Identity, Backup, Operations Tooling, Monitoring. Explicitly no application workloads.
- **Workloads OU** — business workloads, split into Prod and non-prod child OUs.
- **Sandbox OU** — disconnected experimentation; sandbox accounts are never promoted into Workloads.
- **Procedural OUs** — Exceptions, Transitional, Policy Staging, Suspended.

Rules that are non-negotiable: **no workloads in the management account** (SCPs and RCPs never restrict it); **Log Archive is separate from Security Tooling** so whoever configures logging cannot delete the logs; **delegate service administration** to member accounts rather than working from the management account. Depth, quotas, SCP-vs-RCP semantics, and Control Tower in `references/multi-account.md`.

## Tagging Baseline

> Source: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies-enforcement.html (official)

The single most-misunderstood fact, stated by AWS itself: tag-policy basic compliance rules "do not enforce tag compliance on resources that are created without tags... **You cannot use this capability to ensure that required or mandatory tag keys are configured at resource creation.**" Tag policies standardize the *values and capitalization of tags that are present*. To make a tag mandatory you need an **SCP** with `aws:RequestTag`/`aws:TagKeys` conditions on the resource-creating action. Full enforcement-layer map in `references/tagging-governance.md`.

## Resilience and Migration Baseline

> Source: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_planning_for_recovery_disaster_recovery.html and https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-migration/migration-strategies.html (official)

| DR strategy | RTO | RPO | Mechanic |
|---|---|---|---|
| Backup and restore | 24 hours or less | Hours | Redeploy infrastructure and restore data at failover |
| Pilot light | Tens of minutes | Minutes | Data layer always replicating; compute created on failover |
| Warm standby | Minutes | Seconds | Scaled-down but live copy; scale up on failover |
| Multi-site active/active | Near zero | Near zero | All Regions serve traffic; evacuate rather than fail over |

Ordered by increasing cost and complexity, decreasing RTO/RPO. Multi-AZ inside one Region already covers most single-datacenter disasters — escalate to multi-Region only for Region-loss or regulatory scope.

The seven migration strategies are **retire, retain, rehost, relocate, repurchase, replatform, refactor**. AWS's own large-migration guidance: use rehost/replatform/relocate/retire at scale and **modernize after the migration completes**, not during it.

**Currency note — teach both facts.** The certification guides still name AWS Migration Hub, Application Discovery Service, and the Snow Family. As of AWS's current documentation, Migration Hub and Application Discovery Service are **closed to new customers (November 7, 2025)**, Snowball Edge is closed to new customers with **full commercial-Region discontinuation dated December 31, 2026** (Snowcone discontinued November 12, 2024), and **Application Migration Service is now "AWS Transform MGN."** A 2026 migration project provisions AWS Transform, DataSync, and Data Transfer Terminal. Detail in `references/resilience-migration.md`.

## Analytics Baseline

> Source: https://docs.aws.amazon.com/decision-guides/latest/analytics-on-aws-how-to-choose/analytics-on-aws-how-to-choose.html (official)

```
Ingestion:  batch (Glue ETL, DataSync)  OR  streaming (Kinesis Data Streams / Data Firehose / MSK)
Storage:    S3 (Standard -> IA -> Glacier via lifecycle); S3 Tables for Iceberg
Catalog:    Glue Data Catalog, populated by Glue crawlers (Hive Metastore compatible)
Governance: Lake Formation (column/row/cell permissions, LF-Tags, cross-account sharing)
Query:      Athena (ad hoc SQL, $5/TB scanned)  |  EMR (custom Spark/Hadoop/Presto)  |  Redshift
Consume:    Amazon Quick (formerly QuickSight, SPICE)  |  OpenSearch Service (search/log analytics)
```

Selection shortcuts: new to streaming -> Kinesis Data Streams; prefer open source / already on Kafka -> MSK; no consumer application to write, just land the data -> Data Firehose. Custom code across the Hadoop ecosystem -> EMR; serverless catalog-centric ETL -> Glue. Detail in `references/analytics.md`.

## Monthly Cost Anchors

> Source: https://aws.amazon.com/pricing/ (official). Every figure below is PRICE-VOLATILE — anchors for sizing conversations, not quotes.

| Resource | Approximate monthly cost |
|---|---|
| t4g.micro (2 vCPU, 1 GB) | $6 |
| m7g.large (2 vCPU, 8 GB) | $56 |
| m7g.xlarge (4 vCPU, 16 GB) | $112 |
| ALB (base, before LCU) | $16 |
| NAT Gateway per AZ | $32.85 + $0.045/GB |
| EBS gp3 100 GB | $8 |
| S3 Standard 1 TB | $23 |
| Aurora db.r6g.large | $194 |
| RDS db.t4g.micro | $12 |
| ElastiCache cache.t4g.micro | $12 |
| EKS control plane (Standard Support) | $73 |
| Public IPv4 address | $3.60 |
| VPC interface endpoint per ENI/AZ | $7.30 + $0.01/GB |

## Reference Files

- `references/compute.md` — EC2 families and generations, Graviton, pricing models, Lambda cost/limits, ECS vs EKS, Fargate sizing, Auto Scaling, right-sizing, Outposts vs Local Zones vs Wavelength.
- `references/storage.md` — S3 classes, lifecycle, cost components, S3 Tables, EBS volume types and ceilings, EFS three-class model, FSx family.
- `references/database.md` — RDS vs Aurora, Aurora Serverless v2 (including scale-to-zero), DynamoDB capacity and indexes, ElastiCache/MemoryDB with Valkey, RDS Proxy, time-series and warehouse routing.
- `references/networking.md` — VPC layout and CIDR planning, NAT economics, endpoint types, TGW vs peering vs PrivateLink, hybrid DNS, DX vs VPN resiliency tiers, CloudFront, Route 53, ELB.
- `references/security.md` — IAM policy limits and evaluation, SCP/RCP placement in evaluation, KMS costs including rotation, Secrets Manager vs Parameter Store, GuardDuty/Security Hub/Config/WAF pricing and rule strategy.
- `references/security-platform.md` — Well-Architected security pillar, AWS SRA account structure, org-wide Security Hub/GuardDuty/Config/CloudTrail/Access Analyzer deployment, account data-protection defaults, detection-service selection.
- `references/multi-account.md` — Organizations quotas and feature sets, OU taxonomy, management-account rules, SCPs vs RCPs, Control Tower, delegated administration, Identity Center org instance.
- `references/tagging-governance.md` — tag categories and limits, tag-policy semantics, SCP/Config/CloudFormation Guard enforcement layers, cost allocation tags, Resource Explorer/Resource Groups/Config aggregators.
- `references/resilience-migration.md` — RTO/RPO, four DR strategies, DRS and AWS Backup, resilience primitives, 7 Rs, migration phases and TCO, tooling map with currency findings.
- `references/analytics.md` — Athena, Glue, Lake Formation, EMR, Kinesis vs Firehose vs MSK, Amazon Quick, OpenSearch Service, the S3 data-lake composition.
- `references/operations.md` — operational-excellence principles, deployment strategies and rollback, CloudWatch cross-account observability and SLOs, X-Ray, Systems Manager surface.
- `references/serverless.md` — Lambda layers/extensions/edge, concurrency and scaling, API Gateway REST vs HTTP, Step Functions, EventBridge.
- `references/messaging.md` — SQS vs SNS vs EventBridge vs Kinesis, FIFO and high-throughput mode, fan-out patterns, cost shape.
- `references/cost.md` — cost pillar, tooling, purchasing options, right-sizing process, cost traps, estimation templates, checklist.

## Diagnostic Scripts

Read-only AWS CLI FinOps scripts in `scripts/`. All commands, flags, and `--query` paths verified against the official AWS CLI v2 reference on 2026-08-08.

- `scripts/01-account-cost-summary.sh` — month-to-date spend by service with prior-month trend
- `scripts/02-savings-coverage.sh` — Savings Plans / RI coverage and utilization (commitment lever)
- `scripts/03-idle-resource-scan.sh` — unattached volumes, unassociated EIPs, stopped instances (waste lever)

## Sources

- https://aws.amazon.com/pricing/
- https://aws.amazon.com/eks/pricing/
- https://aws.amazon.com/about-aws/whats-new/2024/12/amazon-eks-auto-mode/
- https://aws.amazon.com/ec2/instance-types/graviton/
- https://aws.amazon.com/savingsplans/compute-pricing/
- https://aws.amazon.com/ec2/pricing/reserved-instances/
- https://aws.amazon.com/compute-optimizer/pricing/
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-allocation-strategies.html
- https://aws.amazon.com/vpc/pricing/
- https://aws.amazon.com/rds/features/read-replicas/
- https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.StorageReliability.html
- https://docs.aws.amazon.com/timestream/latest/developerguide/timestream-availability-update.html
- https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-console-comparison.html
- https://aws.amazon.com/elasticache/pricing/
- https://aws.amazon.com/s3/storage-classes/
- https://aws.amazon.com/ebs/volume-types/
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-encryption-faq.html
- https://docs.aws.amazon.com/ebs/latest/userguide/encryption-by-default.html
- https://aws.amazon.com/elasticloadbalancing/pricing/
- https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/
- https://aws.amazon.com/about-aws/whats-new/2024/11/amazon-dynamo-db-reduces-prices-on-demand-throughput-global-tables
- https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/recommended-ous-and-accounts.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/account-structure.html
- https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies-enforcement.html
- https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_planning_for_recovery_disaster_recovery.html
- https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-migration/migration-strategies.html
- https://docs.aws.amazon.com/decision-guides/latest/analytics-on-aws-how-to-choose/analytics-on-aws-how-to-choose.html
- https://aws.amazon.com/privatelink/pricing/

Fetched: 2026-08-08
