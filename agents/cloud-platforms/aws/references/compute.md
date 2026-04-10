# AWS Compute Reference

> EC2, Lambda, ECS, EKS, Fargate, Auto Scaling, right-sizing. Prices are US East (N. Virginia) on-demand.

---

## EC2 Instance Selection

### Instance Family Decision Tree

| Family | Prefix | Choose When | Typical Workloads |
|--------|--------|-------------|-------------------|
| General Purpose | M, T | No single resource dominates; balanced CPU/memory | Web servers, app servers, small-to-mid DBs, dev/test |
| Compute Optimized | C | CPU-bound, highest clock or core density | Batch processing, HPC, ML inference, media encoding, game servers |
| Memory Optimized | R, X, z | Large in-memory datasets, high mem:CPU ratio | In-memory DBs (Redis, SAP HANA), big-data analytics |
| Storage Optimized | I, D, H | High sequential/random IOPS or throughput to local storage | Data warehousing, distributed file systems, HDFS/Kafka |
| Accelerated Computing | P, G, Inf, Trn, DL | GPU/custom silicon for parallel floating-point or inference | ML training (P5), graphics (G5), inference (Inf2), training (Trn1) |
| HPC Optimized | Hpc | Tightly coupled HPC with EFA networking | CFD, molecular dynamics, weather modeling |

### Burstable (T family) Guidance

T instances (t3, t4g) use CPU credits. Suitable ONLY when average CPU is below baseline (20-40%). If you consistently exhaust credits, switch to M-family -- unlimited mode on T instances often costs more than an equivalently sized M instance. Monitor `CPUCreditBalance` CloudWatch metric.

### Generation Strategy

**Always use the latest generation.** Each delivers 20-40% better price/performance with zero application changes.

Current latest (early 2025):
- General: **M7i** (Intel), **M7g** (Graviton3), **M7a** (AMD)
- Compute: **C7i** (Intel), **C7g** (Graviton3), **C7a** (AMD)
- Memory: **R7i** (Intel), **R7g** (Graviton3), **R8g** (Graviton4)
- Accelerated: **P5** (H100), **Inf2** (Inferentia2), **Trn1/Trn2** (Trainium)

### Graviton (ARM) vs x86

Graviton delivers **20-40% better price/performance** than comparable x86:

| Aspect | Graviton (ARM) | x86 (Intel/AMD) |
|--------|---------------|-----------------|
| Price/performance | 20-40% better | Baseline |
| Compatibility | Most Linux, interpreted languages (Python, Node, Java, .NET 6+) | Universal |
| When NOT to use | Windows, legacy x86-only binaries, x86 SIMD dependencies | -- |
| Instance suffix | `g` (m7g, c7g, r7g) | `i` (Intel) or `a` (AMD) |

**Decision rule:** Default to Graviton. Only use x86 when you have a hard x86 dependency.

---

## Pricing Models

### Reserved Instances

| Term | Payment | Savings vs On-Demand |
|------|---------|---------------------|
| 1-year No Upfront | Monthly | ~36% |
| 1-year All Upfront | Pay now | ~42% |
| 3-year No Upfront | Monthly | ~50% |
| 3-year All Upfront | Pay now | ~60% |

### Savings Plans

| Plan Type | Flexibility | Savings |
|-----------|------------|---------|
| Compute Savings Plan | Any instance family, size, OS, region, tenancy + Fargate + Lambda | Up to 66% (3yr all upfront) |
| EC2 Instance Savings Plan | Any size within family+region | Up to 72% (3yr all upfront) |

**Recommendation:** Prefer Compute Savings Plans over RIs for most organizations. Nearly the same savings with far greater flexibility. Use EC2 Instance Savings Plans only when certain about family and region.

### Spot Instances (Up to 90% Savings)

| Strategy | Use Case | Interruption Handling |
|----------|----------|----------------------|
| Batch/CI/CD | Stateless, fault-tolerant jobs | Checkpoint and retry; Spot Fleet capacity-optimized |
| Containers | ECS/EKS worker nodes | Capacity provider: 70% Spot / 30% On-Demand baseline |
| Web tier | Stateless servers behind ASG | Mixed instances: 6+ types, all AZs |
| NOT for Spot | Databases, stateful services, single-instance | -- |

**Key Spot patterns:**
- Diversify across 6+ instance types and all AZs
- Use `capacity-optimized` allocation (not `lowest-price`)
- Implement graceful shutdown via 2-minute warning (instance metadata or EventBridge)

---

## Lambda

### When Lambda Wins

All must be true: request/event-driven, <15 min execution, <10 GB memory, spiky/unpredictable traffic, stateless. Sweet-spot: API backends with variable traffic, file processing, data transformation, scheduled tasks, webhooks.

### When Lambda Loses

Do NOT use when: sustained high throughput (>1M invocations/day = cheaper on containers), >15 minutes, GPU needed, >10 GB RAM, cold-start-sensitive (sub-100ms p99), heavy local storage, persistent connections.

### Cost Model and Break-Even

- Requests: $0.20 per 1M
- Duration: $0.0000166667 per GB-second (1ms granularity)
- Free tier: 1M requests + 400,000 GB-seconds per month

**Break-even vs t4g.small (~$12/mo with Savings Plan):**

| Config | Break-Even |
|--------|-----------|
| 128 MB, 100ms avg | ~3.5M requests/mo |
| 512 MB, 200ms avg | ~800K requests/mo |
| 1024 MB, 500ms avg | ~200K requests/mo |
| 3008 MB, 1s avg | ~35K requests/mo |

**Rule of thumb:** If Lambda runs consistently at >50 concurrent invocations most of the day, investigate container/EC2 alternatives.

### Performance Optimization

**Memory = CPU:** At 1,769 MB you get 1 full vCPU. At 10,240 MB you get 6 vCPUs. For CPU-bound functions, increasing memory may reduce cost (shorter duration offsets higher rate).

**ARM (Graviton2):** 20% lower cost, up to 34% better price/performance. Use `arm64` by default.

**Cold start mitigation (priority order):**

| Strategy | Impact | Cost |
|----------|--------|------|
| ARM + smaller package | 10-30% reduction | Saves 20% |
| SnapStart (Java only) | ~90% reduction | Free |
| Provisioned Concurrency | Eliminates cold start | ~$15/mo per instance at 512 MB |
| Keep-warm pings | Anti-pattern -- unreliable | Wasteful |

### Concurrency

- **Unreserved:** Shares account pool (default 1,000). Risk: one function starves others.
- **Reserved:** Guarantees N slots and acts as throttle ceiling. Free.
- **Provisioned:** Pre-warms N environments. Eliminates cold starts. Costs money.
- **Formula:** Concurrency = invocations/sec x avg duration in seconds

---

## ECS vs EKS

| Factor | ECS | EKS |
|--------|-----|-----|
| Learning curve | Low (AWS concepts only) | Steeper (Kubernetes) |
| Control plane cost | **Free** | $73/month |
| Operational burden | Low | Medium-High (cluster upgrades, add-ons) |
| Portability | AWS-locked | Multi-cloud capable |
| Ecosystem | AWS-native tools | Vast K8s ecosystem (Istio, ArgoCD, Karpenter) |
| Scaling | Task-level auto scaling | HPA, VPA, Karpenter, KEDA |

**Choose ECS** for AWS-native teams, simpler ops, cost-sensitive (free control plane), moderate scale.

**Choose EKS** for existing K8s investment, multi-cloud/hybrid, rich ecosystem needs, complex scheduling, large-scale microservices.

### Fargate vs EC2 Launch Type

| Factor | Fargate | EC2 |
|--------|---------|-----|
| Server management | None (serverless) | You manage instances |
| Per-unit cost | 20-40% higher | Lower with Spot/RIs |
| GPU support | No | Yes |
| Max resources | 4 vCPU / 30 GB (ECS), 16 vCPU / 120 GB (EKS) | Instance limits |
| Fargate Spot | Up to 70% savings | EC2 Spot up to 90% |

**Decision rule:** Start with Fargate for simplicity. Move to EC2 when Fargate cost exceeds operational cost of managing instances, or when you need GPUs/DaemonSets/privileged containers.

---

## Auto Scaling Patterns

| Pattern | Best For |
|---------|----------|
| **Target Tracking** | Most workloads. Maintains metric at target (CPU 50-70%). Start here. |
| **Step Scaling** | Different actions at different thresholds |
| **Predictive Scaling** | Recurring daily/weekly patterns (uses ML forecasting) |
| **Scheduled Scaling** | Known events (sales, batch windows) |

**Mixed Instances Policy (cost optimization):**
- Base capacity: On-Demand (minimum healthy)
- Above base: 70-80% Spot, 20-30% On-Demand
- Instance types: 6+ types for Spot diversity
- Allocation: `capacity-optimized-prioritized`

**Scaling cooldowns:** Scale-out: 60-120s (fast). Scale-in: 300s (slow). Scale out fast, scale in cautiously.

**Warm pool:** Pre-initialized stopped instances for faster scale-out. Useful when boot + init takes minutes. Launch from warm pool in 30-60s vs 3-5 min cold.

---

## Right-Sizing Methodology

1. **Measure:** Enable detailed CloudWatch monitoring (1-min intervals). Collect 2+ weeks. CPU, memory (requires CW agent), network, disk I/O.
2. **Analyze:** Use Compute Optimizer (free basic, $0.0003272/resource/hr enhanced). Analyzes 14 days.
3. **Resize:** Stop, change instance type, start (seconds of downtime). Or use ASG to roll.
4. **Repeat:** Quarterly review cadence.

**Signals:**
- Average CPU < 20% -> downsize (or switch M to T if bursting fits)
- Average memory < 30% -> downsize
- Network below baseline -> smaller instance fine
- EBS IOPS never near provisioned limits -> reduce or switch type
