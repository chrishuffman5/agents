# Azure Compute Reference

> Prices are US East, pay-as-you-go unless noted. Verify at https://azure.microsoft.com/pricing/.

## 1. Virtual Machines

### VM Series Decision Matrix

| Series | Optimized For | vCPU:Memory | Typical Use Cases | Relative Cost |
|--------|--------------|-------------|-------------------|---------------|
| **B-series** (burstable) | Variable workloads | 1:1-4 GiB | Dev/test, low-traffic web, CI runners | Lowest |
| **D-series** (Dv5, Dsv5) | General purpose | 1:4 GiB | Production web/API, app servers, mid-tier DBs | Baseline |
| **E-series** (Ev5, Esv5) | Memory-optimized | 1:8 GiB | In-memory caches, SAP HANA, large DBs | ~20% above D |
| **F-series** (Fsv2) | Compute-optimized | 1:2 GiB | Batch processing, gaming, scientific modeling | ~10% below D per vCPU |
| **L-series** (Lsv3) | Storage-optimized | 1:8 GiB + NVMe | Large NoSQL, data warehousing, log analytics | Premium for local NVMe |
| **N-series** (NC, ND, NV) | GPU | Varies | ML training, inference, rendering, VDI | 2-10x D-series |
| **M-series** | Extreme memory | Up to 4 TB RAM | SAP HANA production, very large in-memory DBs | Premium tier |

### Arm-Based VMs (Dpsv6 / Cobalt 100)

Azure's Arm64 VMs based on Microsoft's custom Cobalt 100 processor:

- **20-30% cost savings** vs equivalent x64 D-series at comparable or better performance.
- Best for: Linux-native workloads, containerized apps, Java/Python/.NET 8+ services, web servers.
- Constraints: Windows Server not supported. Some x86-only software will not run.
- Available in Dpsv6 (general), Epsv6 (memory), and Dplsv6 (storage) variants.
- **Default to Arm for new Linux workloads.** The 20-30% savings compound at scale.

### Disk Selection

| Disk Type | IOPS (max) | Throughput | Cost (1 TiB, approx) | Use Case |
|-----------|-----------|------------|----------------------|----------|
| **Standard HDD** | 500 | 60 MB/s | ~$40/mo | Backups, archives, dev/test cold storage |
| **Standard SSD** | 6,000 | 750 MB/s | ~$77/mo | Dev/test, lightly used production |
| **Premium SSD v2** | 80K (configurable) | 1,200 MB/s | ~$82/mo base + IOPS/throughput | Production databases (sweet spot) |
| **Premium SSD (P-series)** | 20,000 | 900 MB/s | ~$135/mo (P30 1 TiB) | General production |
| **Ultra Disk** | 160,000 | 4,000 MB/s | ~$135/mo + IOPS/throughput | SAP HANA, top-tier databases |

**Premium SSD v2** is the sweet spot for most production -- independently tune IOPS and throughput. Often 30-50% cheaper than P-series for equivalent performance. Use P-series for OS disks (v2 does not support host caching).

**Ephemeral OS disks:** For stateless VMs (VMSS, AKS nodes), use ephemeral OS disks on temp storage or cache. Zero cost, faster reimaging.

### Availability Options

| Option | SLA | Cost Impact |
|--------|-----|-------------|
| Single VM (Premium SSD) | 99.9% | Baseline |
| Availability Set | 99.95% | Free (VM cost only, legacy) |
| Availability Zones | 99.99% | Cross-zone egress ~$0.01/GB |
| VMSS across zones | 99.99% | Same as zones + scale costs |

Always deploy production across Availability Zones. Availability Sets are legacy.

### Spot VMs

Up to **90% discount** on spare capacity. Evicted with 30 seconds notice.

- **Eviction types:** Stop/Deallocate (VM persists) or Delete (stateless workloads).
- **Max price:** Set ceiling or `-1` for market price.
- **Best for:** Batch, CI/CD, fault-tolerant microservices, VMSS scale-out tiers.
- **Not for:** Stateful databases, single-instance production.

### Reserved Instances (RIs)

| Term | Discount vs PAYG | Flexibility |
|------|--------------------|-------------|
| 1-year | ~30-40% | Exchange for same or higher value RI |
| 3-year | ~55-65% | Exchange for same or higher value RI |

Instance size flexibility: D4sv5 RI covers 2x D2sv5 or 0.5x D8sv5 within same series/region. Cancellation: 12% early termination fee on remaining value.

### Azure Savings Plans

Alternative to RIs with more flexibility:

- Commit to fixed hourly spend (e.g., $10/hr) for 1 or 3 years.
- Applies automatically to cheapest eligible compute (VMs, App Service, Container Apps, Functions Premium).
- **Compute savings plan** spans all regions, all VM series, all OS. Maximum flexibility.
- 1-3% less discount than RIs but far more flexible. Use when workloads change frequently.

### Right-Sizing with Azure Advisor

Analyzes 7 days of CPU/memory utilization:
- **Resize:** Over-provisioned VMs (avg CPU <5%, max <20%).
- **Shut down:** Idle VMs with negligible activity.
- **Switch series:** D-series running memory-heavy workloads should be E-series.
- Automate dev/test shutdown schedules -- save 60-70% by running 10hrs/day weekdays only.

---

## 2. App Service

### Plan Tiers

| Tier | Key Features | Monthly Cost (approx) |
|------|--------------|----------------------|
| **Free (F1)** | Shared, 60 min/day, no custom TLS | $0 |
| **Basic (B1-B3)** | Dedicated, TLS, manual scale | $55-220 |
| **Standard (S1-S3)** | Auto-scale (10 instances), 5 slots, VNet | $70-280 |
| **Premium v3 (P1v3-P3v3)** | 20 slots, zone redundancy, enhanced networking | $120-480 |
| **Isolated v2 (I1v2-I3v2)** | Full ASE network isolation | $350-1400 |

**Standard** is the sweet spot for most production -- auto-scale + deployment slots. Premium v3 only for zone redundancy or high scale. Isolated v2 only for strict compliance.

### Critical Configuration

- **Always On:** Enable for Standard+. Without it, app unloads after 20 min idle (cold starts).
- **Deployment Slots:** Use staging slots with swap for zero-downtime deployments. Each slot is a full instance.
- **Health Checks:** Configure `/health` endpoint. Unhealthy instances removed from load balancer.
- **VNet Integration:** Standard+ supports regional VNet integration for outbound to private resources.

### App Service vs AKS vs Container Apps

```
No Kubernetes expertise?
  Simple web app/API -> App Service
  Event-driven/microservices -> Container Apps
Kubernetes expertise?
  Need fine-grained K8s control, custom operators -> AKS
  < 20 microservices, no custom K8s resources -> Container Apps
  Existing K8s manifests/Helm charts -> AKS
```

Cost hierarchy (lowest to highest for equivalent workloads): App Service <= Container Apps < AKS.

---

## 3. Azure Functions

### Hosting Plans

| Plan | Billing | Cold Start | VNet | Scale Limit |
|------|---------|------------|------|-------------|
| **Consumption** | Per-execution + GB-s | Yes (1-10s) | No | 200 instances |
| **Flex Consumption** | Per-execution, always-ready | Configurable | Yes | 1000 instances |
| **Premium (EP1-EP3)** | Reserved instance/hr | No (pre-warmed) | Yes | 100 instances |
| **Dedicated** | App Service plan | No | Yes | Plan limit |

- **Consumption** cheapest for sporadic workloads (<1M exec/month). First 1M executions and 400K GB-s free.
- **Flex Consumption** bridges the gap -- avoid cold starts with always-ready instances.
- **Premium** when you need VNet, larger instances (14 GB RAM), or zero cold starts. Minimum ~$150/mo.
- **Dedicated** when you have spare App Service plan capacity -- marginal zero cost.

### Durable Functions Patterns

| Pattern | Use Case |
|---------|----------|
| Function Chaining | ETL, ordered processing |
| Fan-Out/Fan-In | Batch processing, parallel API calls |
| Async HTTP API | File processing, report generation |
| Monitor | External system health checks |
| Human Interaction | Approval workflows |
| Aggregator (Entity) | Event counters, session state |

Cost note: Durable Functions use Azure Storage for orchestration state. High-throughput orchestrations generate significant storage transactions -- monitor separately.

---

## 4. Azure Kubernetes Service (AKS)

### Tier Selection

| Tier | Control Plane Cost | SLA |
|------|-------------------|-----|
| **Free** | $0 | No SLA, 10 nodes max |
| **Standard** | ~$73/mo | 99.95% (AZ) / 99.9% |
| **Premium** | ~$146/mo | 99.95% (AZ) / 99.9%, LTS |

Free for dev/test. Standard for all production. Premium only for LTS or advanced fleet management.

### Node Pool Strategy

- **System pool:** Small dedicated VMs (D2sv5). Taint with `CriticalAddonsOnly=true:NoSchedule`.
- **General pool:** D4sv5 for standard services.
- **Memory pool:** E4sv5 for caches and data-intensive services.
- **Spot pool:** D4sv5 Spot for batch jobs (up to 90% savings).
- **GPU pool:** NC-series for ML inference (scale to zero when idle).

### Auto-Scaling Stack

| Scaler | Scales | Trigger |
|--------|--------|---------|
| **Cluster Autoscaler** | Node count | Pending unschedulable pods |
| **HPA** | Pod replicas | CPU, memory, custom metrics |
| **VPA** | Pod CPU/memory requests | Historical usage |
| **KEDA** | Pod replicas (scale to zero) | External events (queue, HTTP, cron) |

Combine HPA + Cluster Autoscaler for elastic scaling. Use KEDA for event-driven scale-to-zero. Do not run VPA and HPA on the same metric.

### Networking

| Aspect | Kubenet | Azure CNI | Azure CNI Overlay |
|--------|---------|-----------|-------------------|
| Pod IPs | NAT behind node | VNet IP each | Overlay (not VNet) |
| IP consumption | Low | High | Low |
| Performance | Slight NAT overhead | Best | Good |

**Azure CNI Overlay** is the recommended default. Traditional Azure CNI only when pods must be directly addressable from VNet.

### AKS Cost Checklist

1. Reserved Instances on node VMs (30-65% savings).
2. Spot node pools for batch and CI/CD.
3. Cluster stop/start for dev/test (saves 100% of node compute).
4. KEDA scale-to-zero for event-driven workloads.
5. Right-size pods with VPA recommendations.
6. Node auto-provisioning (NAP/Karpenter) for optimal VM selection.

---

## 5. Container Apps

### When to Prefer Over AKS

- Team lacks Kubernetes expertise.
- Microservices, APIs, event-driven, or background jobs.
- Built-in Dapr for service communication, state, pub/sub.
- Scale-to-zero is important for cost.
- Simple traffic splitting for blue/green or canary.

### Plans

| Plan | Billing | Use Case |
|------|---------|----------|
| **Consumption** | Per-vCPU-second + GiB-second | Most workloads, scale-to-zero |
| **Dedicated** | Reserved D-series profiles | Compliance, consistent performance, GPU |

Consumption pricing: ~$62/mo (1 vCPU 24/7), ~$8/mo (1 GiB 24/7). First 180K vCPU-seconds and 360K GiB-seconds free.

### Cost Comparison (Single Service, 24/7)

| Service | Config | Monthly Cost |
|---------|--------|--------------|
| Functions Consumption | 100K exec/month | $0 (free tier) |
| Container Apps Consumption | 0.5 vCPU / 1 GiB | ~$39 |
| App Service Basic B1 | 1 vCPU / 1.75 GiB | ~$55 |
| App Service Standard S1 | 1 vCPU / 1.75 GiB | ~$70 |
| Functions Premium EP1 | 1 vCPU / 3.5 GiB | ~$150 |
| Container Apps Dedicated | D4 profile | ~$200 |
| AKS (2-node D2sv5 + Standard) | 2 vCPU / 8 GiB | ~$220 |

For always-on services, App Service is often cheapest. For variable workloads, Container Apps Consumption or Functions Consumption wins.
