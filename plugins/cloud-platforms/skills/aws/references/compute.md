# AWS Compute Reference

> EC2, Lambda, ECS, EKS, Fargate, Auto Scaling, right-sizing, edge/hybrid compute. Prices are US East (N. Virginia) on-demand and are PRICE-VOLATILE unless flagged as a structural fact.

---

## EC2 Instance Selection

### Instance Family Decision Tree

> Source: https://aws.amazon.com/ec2/instance-types/ (official)

| Family | Prefix | Choose when | Typical workloads |
|---|---|---|---|
| General Purpose | M, T | No single resource dominates | Web/app servers, small-to-mid DBs, dev/test |
| Compute Optimized | C | CPU-bound, high clock or core density | Batch, HPC, ML inference, media encoding, game servers |
| Memory Optimized | R, X, z | Large in-memory datasets | In-memory DBs, SAP HANA, big-data analytics |
| Storage Optimized | I, D, H | High local-disk IOPS or throughput | Data warehousing, distributed filesystems, Kafka |
| Accelerated Computing | P, G, Inf, Trn, DL | GPU or custom silicon | ML training (P5, Trn2), graphics (G5), inference (Inf2) |
| HPC Optimized | Hpc | Tightly coupled HPC with EFA | CFD, molecular dynamics, weather modeling |

### Generation Strategy

> Source: https://aws.amazon.com/about-aws/whats-new/2024/07/amazon-ec2-r8g-instances-aws-graviton4-generally-available/, https://aws.amazon.com/about-aws/whats-new/2024/09/amazon-ec2-c8g-m8g-instances/, https://aws.amazon.com/ec2/instance-types/m8g/, https://www.aboutamazon.com/news/aws/aws-graviton-5-cpu-amazon-ec2, https://aws.amazon.com/about-aws/whats-new/2024/12/amazon-ec2-trn2-instances-available, https://aws.amazon.com/ec2/instance-types/trn2/ (official)

**Use the latest generation available in your Region.** Each generation delivers materially better price/performance with no application change.

- **Graviton4 (`8g`) is the safe default baseline.** R8g reached GA July 9, 2024 with up to 30% better performance than Graviton3-based R7g (30% faster web applications, 40% faster databases, 45% faster large Java applications); R8g scales 1-192 vCPU and 8 GB-1,536 GB, with R8gd (local NVMe), R8gn (network-optimized), and R8gb (storage-optimized) variants. C8g and M8g reached GA September 25, 2024 with "up to 30% better performance and larger instance sizes with up to 3x more vCPUs and memory than" M7g.
- **Graviton5 (`9g`) is the new frontier.** M9g/M9gd reached GA June 10, 2026 (C9g/R9g rolling out): 192 cores, 3 nm, 2.6x more L3 cache per core than Graviton4, DDR5-8800, PCIe Gen 6. Versus Graviton4: up to 25% better overall compute, 35% faster web apps, 35% faster ML inference, 30% faster databases, 15% higher network bandwidth, 20% higher EBS bandwidth.
- **Accelerated:** P5 (H100), Inf2 (Inferentia2), **Trn2 GA December 3, 2024** — Trn2 UltraServers pair 64 Trainium2 chips for up to 83.2 petaflops FP8, and the Trn2 instance page states "30-40% better price performance than GPU-based EC2 P5e and P5en instances."

### Graviton (ARM) vs x86

> Source: https://aws.amazon.com/ec2/instance-types/graviton/ (official)

AWS's own framing splits cost and performance rather than merging them: **up to 20% lower cost** than comparable x86 instances, **up to 30-40% better performance** on compute-bound workloads (databases, Java), and **up to 60% less energy**.

| Aspect | Graviton (ARM) | x86 (Intel/AMD) |
|---|---|---|
| Cost | Up to 20% lower | Baseline |
| Compatibility | Most Linux, Python, Node, Java, .NET 6+ | Universal |
| Do not use for | Windows, x86-only binaries, x86 SIMD dependencies | -- |
| Suffix | `g` (m8g, c8g, r8g) | `i` (Intel), `a` (AMD) |

**Rule:** default to Graviton; require a stated hard x86 dependency to opt out. Graviton has no Windows support — a Windows-containing fleet is an automatic disqualifier.

### Burstable (T family)

> Source: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances.html (official)

T instances run on CPU credits and suit workloads averaging below baseline (roughly 20-40% CPU). **T4g (Graviton2) is the current default choice** — AWS states up to 40% higher price/performance and 20% lower cost than T3, and it is Free Tier eligible for accounts created after July 15, 2025 (alongside t3.micro/small). T instances can save up to 15% versus M instances for suitable workloads. Monitor `CPUCreditBalance`; if credits are consistently exhausted, move to M — sustained unlimited-mode surcharges often exceed an equivalent M instance.

---

## Pricing Models

### Reserved Instances

> Source: https://aws.amazon.com/ec2/pricing/reserved-instances/ (official)

Terms are 1 or 3 years; payment options are No Upfront, Partial Upfront, All Upfront. Discounts differ by RI type and are PRICE-VOLATILE:

- **Standard RIs** — up to ~40% (1 year), up to ~60% (3 year), maximum "up to 72%". Cannot change instance family.
- **Convertible RIs** — up to ~31% (1 year), up to ~54% (3 year), maximum "up to 66%". Can be exchanged for a different family/OS/tenancy.

Treat these as materially different products; the flexibility premium is the price gap.

### Savings Plans

> Source: https://aws.amazon.com/savingsplans/compute-pricing/ (official)

| Plan | Flexibility | Max discount |
|---|---|---|
| Compute Savings Plan | Any EC2 family/size/AZ/Region/OS/tenancy, **plus Fargate and Lambda** | Up to 66% (3yr all-upfront) |
| EC2 Instance Savings Plan | Any size/AZ/OS/tenancy within one family in one Region | Up to 72% (3yr all-upfront) |

Prefer Compute Savings Plans for most organizations — you can move EC2 workloads onto Fargate without losing the discount. Use EC2 Instance Savings Plans only where family and Region are certain for the whole term.

### Spot Instances

> Source: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-allocation-strategies.html (official)

Up to 90% off on-demand for interruption-tolerant workloads: batch, CI/CD, stateless web tiers behind an ASG, container worker nodes. Never for databases, stateful singletons, or anything that cannot absorb a 2-minute interruption notice.

Allocation strategies AWS currently documents: **`price-capacity-optimized`** (balances price and capacity — the modern default for most Auto Scaling and Spot Fleet cases), **`capacity-optimized`** (deepest-capacity pools, AWS's long-standing recommendation), **`capacity-optimized-prioritized`** (capacity-optimized within an explicit priority order), and `lowest-price` (highest interruption risk). Diversify across 6+ instance types and every AZ; handle the 2-minute interruption notice with checkpointing.

---

## Lambda

> Source: https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html and https://docs.aws.amazon.com/lambda/latest/dg/configuration-memory.html (official)

### When Lambda wins / loses

Wins when all hold: event-driven, under the **900 second (15 minute)** timeout, within the **128 MB - 10,240 MB** memory range, spiky traffic, stateless. Loses on sustained high throughput (containers become cheaper), >15 minutes, GPU need, >10 GB RAM, sub-100 ms p99 cold-start sensitivity, heavy local storage, or persistent connections.

Cost model (structure is stable; digits are PRICE-VOLATILE): per-request charge plus per-GB-second duration charge at 1 ms granularity, with a monthly free tier of requests and GB-seconds.

**Rule of thumb:** if the function runs at >50 concurrent invocations for most of the day, price a container alternative.

### Performance

> Source: https://docs.aws.amazon.com/lambda/latest/dg/configuration-memory.html and https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html (official)

- **Memory buys CPU.** AWS documents exactly one anchor: "At 1,769 MB, a function has the equivalent of one vCPU." CPU scales proportionally with memory up to 10,240 MB — roughly six vCPU-equivalent at the ceiling, but AWS does not publish that figure, so do not assert it as a documented number. For CPU-bound functions, more memory can *lower* total cost by shortening duration.
- **`arm64` (Graviton2)** is the default architecture choice: lower cost and generally better price/performance.
- **SnapStart is no longer Java-only.** It supports **Java 11 and later, Python 3.12 and later, and .NET 8 and later**. Container images and OS-only runtimes are unsupported, and SnapStart cannot be combined with Provisioned Concurrency, EFS, S3 Files, or >512 MB ephemeral storage on the same function version. **Pricing differs by runtime: free for Java; Python and .NET incur caching and restoration charges based on memory.**

Cold-start levers in priority order: `arm64` plus a smaller deployment package -> SnapStart (where the runtime supports it) -> Provisioned Concurrency (paid, eliminates cold starts). Keep-warm pings are an anti-pattern.

### Quotas and layers

- Function layers: **5**; deployment package unzipped including layers and custom runtimes: **250 MB**.
- Default account concurrency: **1,000** (adjustable). Reserved concurrency is free and acts as both floor and ceiling; Provisioned Concurrency is paid and pre-warms environments.
- Concurrency = invocations per second x average duration in seconds.
- **A second, independent throttle exists:** a requests-per-second limit of **10x the concurrency limit** (default 1,000 concurrency implies a 10,000 req/s ceiling). Very short functions can throttle on RPS while concurrency still looks healthy.

---

## ECS vs EKS

> Source: https://aws.amazon.com/eks/pricing/ and https://aws.amazon.com/about-aws/whats-new/2024/12/amazon-eks-auto-mode/ (official)

| Factor | ECS | EKS |
|---|---|---|
| Control plane cost | Free | **$0.10/cluster-hour** Standard Support (~$73/mo); **$0.60/cluster-hour** Extended Support |
| Learning curve | Low (AWS concepts only) | Steeper (Kubernetes) |
| Operational burden | Low | Medium — or **Low with EKS Auto Mode** |
| Portability | AWS-locked | Multi-cloud capable |
| Ecosystem | AWS-native | Istio, ArgoCD, Karpenter, KEDA |

**Extended Support** applies to clusters running a Kubernetes version past the 14-month standard window, extending support to 26 months total at 6x the hourly rate. Treat it as a budgeting signal that the upgrade is overdue, not a supported steady state.

**EKS Auto Mode** (GA December 2024) automates compute, storage, and networking management for EKS clusters: it selects and provisions EC2 instances, handles OS patching and security upgrades, and scales capacity dynamically. AWS frames it as removing the need for "deep expertise, ongoing infrastructure management, or capacity planning." Available on Kubernetes 1.29+ in all commercial Regions (not GovCloud or China), with no upfront fee — you pay for the managed resources plus standard EC2 costs. It substantially narrows the "EKS is operationally heavier" argument, so recommend ECS on AWS-native simplicity and cost grounds rather than on ops burden alone.

### Fargate vs EC2 launch type

> Source: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html and https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html (official)

| Factor | Fargate | EC2 |
|---|---|---|
| Server management | None | You manage instances |
| Per-unit cost | Higher (PRICE-VOLATILE premium) | Lower with Spot/RIs |
| GPU support | No | Yes |
| Max task/pod size (ECS) | **16 vCPU / 32-120 GB** standard, plus a **32 vCPU / 60, 120, or 244 GB** tier (Linux only, platform 1.4.0+) | Instance limits |
| Max pod size (EKS) | **16 vCPU / 32-120 GB** (no 32 vCPU tier) | Instance limits |
| Spot | Fargate Spot | EC2 Spot up to 90% |

**EKS Fargate pod-sizing gotcha:** Fargate adds **256 MB of memory overhead per pod** for kubelet, kube-proxy, and containerd. A pod requesting 1 vCPU / 8 GB provisions a 2 vCPU / 9 GB task, because no 1 vCPU / 9 GB combination exists. Size requests against the published combination table, not against the raw request.

**Rule:** start on Fargate for simplicity; move to EC2 when Fargate's per-unit premium exceeds the operational cost of managing instances, or when you need GPUs, DaemonSets, or privileged containers.

---

## Auto Scaling Patterns

| Pattern | Best for |
|---|---|
| Target Tracking | Most workloads. Hold a metric at target (CPU 50-70%). Start here. |
| Step Scaling | Different responses at different breach magnitudes |
| Predictive Scaling | Recurring daily/weekly shapes (ML forecasting) |
| Scheduled Scaling | Known events (sales windows, batch runs) |

Mixed-instances policy for cost: On-Demand base capacity for the minimum healthy fleet, 70-80% Spot above it, 6+ instance types for Spot diversity, `capacity-optimized-prioritized` or `price-capacity-optimized` allocation. Scale out fast (60-120 s cooldown), scale in slowly (300 s). Warm pools pre-initialize stopped instances when boot plus init takes minutes.

---

## Right-Sizing Methodology

> Source: https://aws.amazon.com/compute-optimizer/pricing/ and https://docs.aws.amazon.com/compute-optimizer/latest/ug/what-is-compute-optimizer.html (official)

1. **Measure.** Detailed CloudWatch monitoring at 1-minute intervals for 2+ weeks; CPU, memory (requires the CloudWatch agent), network, disk I/O.
2. **Analyze with Compute Optimizer.** Basic recommendations are **free** over a **14-day** lookback. The **enhanced/paid tier is $0.0003360215 per resource-hour** and extends the lookback to **about three months (93 days)** — distinguish the two lookbacks when quoting them.
3. **Resize.** Stop, change type, start; or roll through an Auto Scaling group.
4. **Repeat quarterly.**

Practitioner thresholds (not AWS-published rules): average CPU <20% -> downsize; <5% -> investigate termination; average memory <30% -> downsize; sustained network well below the instance limit -> smaller type.

---

## Edge and Hybrid Compute Placement

> Source: https://aws.amazon.com/outposts/ and https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/perf_networking_choose_workload_location_network_requirements.html (official)

Well-Architected's three-way split, close to verbatim: "Use AWS Local Zones to run workloads like video rendering... Use AWS Outposts for workloads that need to remain on-premises and where you want that workload to run seamlessly with the rest of your other workloads in AWS... For [applications requiring] ultra-low-latency for 5G devices, consider AWS Wavelength."

- **Local Zones** — AWS-operated infrastructure closer to a metro population. No customer facility, no on-premises data-residency requirement.
- **Outposts** — AWS-managed racks or servers in a customer-owned or customer-selected facility, for workloads that must physically stay on-premises (compliance, deep on-prem dependencies, phased migration of latency-coupled legacy apps) while using native AWS APIs via a service link back to a home Region.
- **Wavelength** — inside a telco 5G network edge, for mobile-device ultra-low latency specifically.

Cost framing for the hybrid-compute question: Outposts is a committed-capacity purchase, so its cost optimization is capacity planning and workload placement, not on-demand elasticity — the opposite lever from the rest of this file.

## Sources

- https://aws.amazon.com/ec2/instance-types/
- https://aws.amazon.com/ec2/instance-types/graviton/
- https://aws.amazon.com/about-aws/whats-new/2024/07/amazon-ec2-r8g-instances-aws-graviton4-generally-available/
- https://aws.amazon.com/about-aws/whats-new/2024/09/amazon-ec2-c8g-m8g-instances/
- https://aws.amazon.com/ec2/instance-types/m8g/
- https://aws.amazon.com/ec2/instance-types/r8g/
- https://www.aboutamazon.com/news/aws/aws-graviton-5-cpu-amazon-ec2
- https://aws.amazon.com/about-aws/whats-new/2024/12/amazon-ec2-trn2-instances-available
- https://aws.amazon.com/ec2/instance-types/trn2/
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances.html
- https://aws.amazon.com/ec2/pricing/reserved-instances/
- https://aws.amazon.com/savingsplans/compute-pricing/
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-allocation-strategies.html
- https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html
- https://docs.aws.amazon.com/lambda/latest/dg/configuration-memory.html
- https://docs.aws.amazon.com/lambda/latest/dg/lambda-concurrency.html
- https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html
- https://aws.amazon.com/eks/pricing/
- https://aws.amazon.com/about-aws/whats-new/2024/12/amazon-eks-auto-mode/
- https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
- https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html
- https://aws.amazon.com/compute-optimizer/pricing/
- https://docs.aws.amazon.com/compute-optimizer/latest/ug/what-is-compute-optimizer.html
- https://aws.amazon.com/outposts/
- https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/perf_networking_choose_workload_location_network_requirements.html

Fetched: 2026-08-08
