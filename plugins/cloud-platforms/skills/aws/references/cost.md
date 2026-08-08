# AWS Cost Optimization Reference

> Cost pillar, cost-management tooling, purchasing options, right-sizing process, cost traps, estimation templates. Prices are US East (N. Virginia) and PRICE-VOLATILE; billing models are structural facts.

---

## Cost Optimization Framework

> Source: https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/design-principles.html (official)

The Well-Architected cost pillar's five design principles, verbatim titles:

1. **Implement cloud financial management** — dedicate ownership of cost as a discipline.
2. **Adopt a consumption model** — pay for what you consume, scale down when you do not.
3. **Measure overall efficiency** — track business output per dollar.
4. **Stop spending money on undifferentiated heavy lifting** — use managed services.
5. **Analyze and attribute expenditure** — tag everything and allocate cost to teams.

AWS's own worked example for principle 2: stopping non-production resources outside working hours is "a potential cost savings of 75% (40 hours versus 168 hours)."

Principle 5 is the tagging strategy — see `references/tagging-governance.md` for the mechanics of making it real.

---

## Cost Management Tooling

### Cost Explorer

> Source: https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html and https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/ (official)

Free in the console. Once enabled it cannot be disabled. View up to 13 months of history and forecast up to 18 months, by service, account, tag, Region, or instance type, with Savings Plans and reservation-utilization reporting.

**API charge — $0.01 per paginated API request, not per thousand.** The user guide states "Each paginated API request incurs a charge of **$0.01**," and the pricing page states it independently: "Each request using your primary billing view, which contains cost management data associated with your account, will incur a cost of $0.01." **Custom billing views bill $0.01 *per source*** — a view combining five billing sources costs $0.05 per request. Material quoting "$0.01 per 1,000 requests" understates programmatic Cost Explorer use by three orders of magnitude; budget accordingly before wiring Cost Explorer into a dashboard refresh loop.

**Do not conflate that with the hourly-granularity charge**, which is a separate billable dimension: "Cost Explorer offers hourly granularity at a daily charge of $0.00000033 per usage record (which translates to $0.01 per 1,000 usage records monthly)." The per-1,000 figure belongs to usage records, not API requests — that conflation is the likely origin of the stale metric.

Cost Explorer now embeds **Amazon Q Developer** for natural-language cost questions on any report — the fastest entry point for someone new to the tool.

### AWS Budgets

> Source: https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/ (official)

**Budget monitoring and alerting is free and unlimited.** Only **Budget Actions** are metered: "Your first two action-enabled budgets are free... each subsequent action-enabled budget will incur a **$0.10 daily cost**."

Two corrections at once versus older material: the rate is **$0.10/day, not $0.01/day**, and the free/paid split applies **only to action-enabled budgets** — plain cost and usage alerts never cost anything regardless of how many you create. Create alert budgets liberally; ration Budget Actions (auto-stop EC2, apply an IAM deny policy) to the few places automated enforcement is genuinely wanted.

### Compute Optimizer

> Source: https://docs.aws.amazon.com/compute-optimizer/latest/ug/what-is-compute-optimizer.html and https://aws.amazon.com/compute-optimizer/pricing/ (official)

- Default analysis window: **14 days** of CloudWatch metrics. Free.
- Enhanced infrastructure metrics (paid opt-in, **$0.0003360215 per resource-hour**) extend the lookback to **93 days**.
- **Coverage is far wider than EC2/Lambda/EBS/Fargate:** it now also covers **EC2 Auto Scaling groups, Aurora and RDS databases, NAT Gateway, DynamoDB, ElastiCache, MemoryDB, DocumentDB, WorkSpaces, SageMaker, and commercial software licenses.**

That coverage matters for the traps below: idle RDS, oversized ElastiCache, and DynamoDB capacity-mode choices now all have a native recommendation path rather than requiring a hand-built CloudWatch threshold review.

### Trusted Advisor

> Source: https://docs.aws.amazon.com/awssupport/latest/user/support-plans-eos.html, https://aws.amazon.com/premiumsupport/plans/, https://aws.amazon.com/blogs/aws/new-and-enhanced-aws-support-plans-add-ai-capabilities-to-expert-guidance/ (official)

Full checks require a paid support tier above Basic, and **the plan lineup has been restructured — get the framing right:**

- **Business Support+ is a new tier, not a renamed Business Support.** AWS's own language is "new and enhanced," and it is the upgrade destination for *both* predecessor plans: "Customers with Developer Support can continue using their existing plan or choose to upgrade to Business Support+ anytime before January 1, 2027," with an identical notice for Business Support. It unlocks more than 500 Trusted Advisor checks.
- **Three plans are discontinued on January 1, 2027: Developer Support, Business Support, and Enterprise On-Ramp.** Existing customers keep their plan until then or migrate early; **Enterprise On-Ramp customers "will be automatically upgraded to AWS Enterprise Support."**
- **Enterprise Support now starts at $5,000/month**, "a 67% savings over the previous Enterprise Support minimum price" of $15,000.
- The current public plans page lists **Basic, Business Support+, Enterprise Support, and Unified Operations** — the classic Developer and Business tiers no longer appear at all.

Say "Business Support+ or Enterprise Support," and never describe Business Support+ as a rename.

Key cost checks: low-utilization EC2, underutilized EBS volumes, unassociated Elastic IPs, idle load balancers, idle RDS instances.

### S3 Storage Lens

> Source: https://aws.amazon.com/s3/storage-lens/ (official)

Organization-wide S3 visibility: bucket sizes, access patterns, cost efficiency. **The free tier provides 62 metrics** (unique and derived) at bucket level with 14 days of historical data — not 28. Advanced metrics are billed per million objects monitored (rate is PRICE-VOLATILE). Use it to find buckets with no lifecycle policy, version bloat, and noncurrent-version accumulation.

---

## Purchasing Options

> Source: https://docs.aws.amazon.com/savingsplans/latest/userguide/what-is-savings-plans.html (official)

| Feature | Savings Plans | Reserved Instances |
|---|---|---|
| Flexibility | Compute SP: any family/size/AZ/Region/OS/tenancy. EC2 Instance SP: one family in one Region | Locked to type and Region (Convertible RIs allow family change) |
| Services covered | EC2, Fargate, Lambda | EC2, RDS, ElastiCache, OpenSearch, Redshift |
| Max discount | "Up to 72% on your AWS compute workloads" | Up to 72% (Standard), up to 66% (Convertible) |
| Payment options | All Upfront, Partial Upfront, No Upfront | Same |

**Three plan types, not two.** Alongside Compute Savings Plans and EC2 Instance Savings Plans, AWS documents **SageMaker AI Savings Plans** — "lower prices for your Amazon SageMaker AI instance usage, regardless of instance family, size, component, or Region." It is a separate commitment from a Compute Savings Plan and is easy to miss on accounts with significant SageMaker spend.

**Start with Compute Savings Plans.** Move to EC2 Instance Savings Plans only where family and Region are certain for the whole term. Use Reserved Instances where there is no Savings Plans option at all (RDS, ElastiCache, OpenSearch, Redshift).

**Spot** for batch, CI/CD runners, data processing, and stateless web tiers behind a mixed-instances ASG. Never for databases, stateful services, or anything that cannot absorb a 2-minute interruption notice.

---

## Right-Sizing Process

1. **Identify candidates** with Compute Optimizer plus Cost Explorer right-sizing recommendations.
2. **Validate** against at least two weeks of CloudWatch data — CPU, memory via the CloudWatch agent, network, disk.
3. **Apply thresholds.** These are practitioner heuristics, not AWS-published rules — present them as such: CPU average under 20% over 14 days suggests downsizing; under 5% suggests the resource may be unused; memory average under 30% suggests a smaller class; network well under the instance limit confirms headroom.
4. **Implement gradually** — one instance at a time, observe 48 hours.
5. **Automate the recurring wins** — an instance scheduler for non-production (AWS's own cost pillar cites ~75% for a 40-hour week).

---

## Common Cost Traps

### Networking — usually the biggest surprise

> Source: https://aws.amazon.com/vpc/pricing/ and https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/ (official)

- **NAT Gateway:** $0.045/hour (**$32.85/month**) plus **$0.045/GB** processed. One terabyte per month through a single NAT Gateway is $45 of data processing on top of $32.85 of standing charge. Fix with free S3/DynamoDB gateway endpoints and interface endpoints for high-volume services.
- **Cross-AZ data transfer:** $0.01/GB each direction. Chatty microservices spread across AZs accumulate this continuously. Fix with AZ-affinity routing where availability requirements allow.
- **Public IPv4 addresses:** **$0.005/hour (~$3.60/month) for every public IPv4 address, attached or not, since February 1, 2024.** Fix by adopting IPv6 where possible and auditing for unused allocations.

### Compute

- **Over-provisioned Lambda memory.** Doubling memory that the function does not use doubles the GB-second charge. Run a power-tuning sweep — for CPU-bound functions more memory can lower total cost by cutting duration, and for I/O-bound functions it purely wastes money.
- **Idle RDS instances.** A production-class instance running unused is one of the largest silent line items in most accounts. Note that a stopped RDS instance auto-restarts after 7 days. Fix with an instance scheduler, or Aurora Serverless v2 with a **0 ACU minimum** so an idle database stops billing compute entirely.
- **Unattached EBS volumes.** Billed at full rate. Find them with `scripts/03-idle-resource-scan.sh` and set `DeleteOnTermination` appropriately at launch.

### Storage and data

> Source: https://aws.amazon.com/dynamodb/pricing/on-demand/ and https://aws.amazon.com/about-aws/whats-new/2024/11/amazon-dynamo-db-reduces-prices-on-demand-throughput-global-tables (official)

- **DynamoDB On-Demand at sustained throughput.** Still a genuine trap, **but size it against post-cut prices.** AWS reduced on-demand throughput prices by ~50% effective **November 1, 2024** — the current on-demand write-request rate is roughly half what older material assumes, and read requests moved the same way. A sustained 1,000 writes/second workload is therefore about **$1,620/month on-demand**, not $3,240, and switching to right-sized Provisioned saves roughly **70%, not 85%**. The recommendation is unchanged; the arithmetic is not.
- **S3 versioning without lifecycle.** Every overwrite stores another full version. Fix with `NoncurrentVersionExpiration` or `NewerNoncurrentVersions`.
- **CloudWatch Logs ingestion at $0.50/GB.** Verbose application logging at 10 GB/day is $150/month in ingestion alone before storage. Fix by filtering at the source, setting retention on every log group, and keeping DEBUG out of production.

### Database

- **Aurora Standard mode with heavy I/O.** Switch to I/O-Optimized once I/O exceeds 25% of total Aurora spend (AWS's own stated breakpoint). See `references/database.md` for the 30-day switch cadence and restart implications.
- **Non-production caches sized like production.** Use a `t4g` node class or ElastiCache Serverless; and prefer **Valkey**, which AWS prices ~20% below node-based Redis OSS and ~33% below Serverless Redis OSS.
- **DynamoDB GSI over-indexing.** Each GSI multiplies write cost. Audit for unused indexes; use sparse indexes and `KEYS_ONLY` projections.
- **Read-replica sprawl.** Standing replicas "just in case" bill as full instances. Use Aurora Auto Scaling with a minimum of 1.

---

## "How Do I Reduce My AWS Bill by 30%?"

Ordered by typical impact:

1. Savings Plans and RIs on steady-state compute and databases
2. Right-size over-provisioned resources (Compute Optimizer)
3. Storage tiering and lifecycle policies
4. Eliminate waste — unattached EBS, idle RDS, unassociated EIPs, forgotten Regions
5. VPC endpoints to remove NAT data-processing charges
6. Spot for interruption-tolerant workloads
7. Auto Scaling to match capacity to demand
8. Non-production scheduling
9. DynamoDB capacity-mode review
10. CloudWatch Logs filtering and retention

---

## Cost Estimation Templates

All figures are PRICE-VOLATILE illustrations of *shape* — which line dominates — not quotes.

### Web application stack (~$625/mo on-demand, ~$470/mo with Savings Plans)

```
Compute   2x m7g.large Multi-AZ                $112
ALB       base + LCU                            $26
Aurora    db.r6g.large + 100 GB storage        $204
Cache     ElastiCache cache.r6g.large          $165
S3        500 GB + requests                     $19
NAT       2 AZs + 100 GB processed              $70
CloudWatch                                      $10
Egress    200 GB out                            $18
```

Dominant lever: the database and cache pair, then the commitment discount.

### Serverless API (~$14/mo)

```
Lambda      2M invocations, 256 MB, 200 ms       $2
API Gateway HTTP API, 2M requests                $2
DynamoDB    on-demand, light usage               $3
S3          50 GB                                $1
CloudWatch                                       $5
```

Dominant lever: CloudWatch, which is easy to overlook at this scale.

### Data pipeline (~$340/mo)

```
Kinesis     2 shards provisioned                $22
Lambda      50M invocations, 512 MB, 500 ms    $218
S3          1 TB cumulative with lifecycle      $23
Athena      100 GB/mo scanned                    $1
CW Logs     5 GB/day                            $75
```

Dominant lever: Lambda duration (roughly 60% of the total). Second lever: log volume. Athena cost falls further with Parquet plus partitioning — AWS's own example cites 3x from compression and 4x from columnar projection.

---

## Cross-Cutting Checklist

**Compute** — Graviton where compatible; latest generation; Compute Optimizer reviewed quarterly; Savings Plans on steady state; Spot for fault-tolerant work; Auto Scaling configured; Lambda on `arm64` with tuned memory; Fargate tasks right-sized against the published CPU/memory combinations.

**Networking** — S3 and DynamoDB gateway endpoints in every VPC; interface endpoints for high-traffic services; NAT data processing reviewed monthly; single NAT in non-production; CloudFront price class appropriate (and flat-rate plans evaluated); ALBs consolidated with host-based routing; Alias records instead of CNAMEs.

**Storage and data** — all gp2 migrated to gp3; lifecycle policies on every bucket; EFS lifecycle extended through Archive, not stopping at IA; unattached EBS deleted; DynamoDB capacity mode reviewed; CloudWatch Logs retention set; Aurora I/O mode evaluated.

**Security** — KMS key types matched to requirement and **rotation cost budgeted at ~$3/month per rotated CMK**; S3 Bucket Keys enabled with SSE-KMS; secrets and parameters cached in the application; Parameter Store Standard for non-secret configuration; GuardDuty protection plans chosen deliberately; Config recording scoped to governed resource types.

## Sources

- https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/design-principles.html
- https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html
- https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/
- https://aws.amazon.com/aws-cost-management/pricing/
- https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/
- https://docs.aws.amazon.com/compute-optimizer/latest/ug/what-is-compute-optimizer.html
- https://aws.amazon.com/compute-optimizer/pricing/
- https://docs.aws.amazon.com/awssupport/latest/user/support-plans-eos.html
- https://aws.amazon.com/premiumsupport/plans/
- https://aws.amazon.com/premiumsupport/plans/business-plus/
- https://aws.amazon.com/blogs/aws/new-and-enhanced-aws-support-plans-add-ai-capabilities-to-expert-guidance/
- https://aws.amazon.com/s3/storage-lens/
- https://docs.aws.amazon.com/savingsplans/latest/userguide/what-is-savings-plans.html
- https://aws.amazon.com/vpc/pricing/
- https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/
- https://aws.amazon.com/dynamodb/pricing/on-demand/
- https://aws.amazon.com/about-aws/whats-new/2024/11/amazon-dynamo-db-reduces-prices-on-demand-throughput-global-tables
- https://aws.amazon.com/elasticache/pricing/
- https://aws.amazon.com/athena/pricing/

Fetched: 2026-08-08
