# GCP Compute Reference

> Prices are us-central1, on-demand unless noted. Verify at https://cloud.google.com/pricing.

## 1. Compute Engine (IaaS VMs)

### Machine Type Families

| Family | Series | Use Case | vCPU:Memory |
|--------|--------|----------|-------------|
| General Purpose | E2 | Cost-optimized, dev/test | 1:0.5-8 GB |
| General Purpose | N2/N2D | Balanced production | 1:1-8 GB |
| General Purpose | N4 | Latest gen (Emerald Rapids) | 1:1-8 GB |
| Compute Optimized | C3/C3D | HPC, gaming, single-thread | 1:2-4 GB |
| Memory Optimized | M3 | SAP HANA, in-memory DBs | 1:14.9 GB |
| Accelerator Optimized | A2 | ML training (A100 GPUs) | Fixed configs |
| Accelerator Optimized | A3 | ML training (H100, 200Gbps GPU-GPU) | Fixed configs |
| Accelerator Optimized | G2 | ML inference (L4 GPUs) | Fixed configs |

### Custom Machine Types (Unique to GCP)

Specify exact vCPU (1-96) and memory (0.9-6.5 GB per vCPU). Eliminates over-provisioning.
- Extended memory: up to 12 GB/vCPU for memory-intensive workloads.
- Available for N1, N2, N2D, E2 families.
- No equivalent in AWS/Azure -- they force fixed instance sizes.

### Pricing Reference (on-demand, per hour)

- e2-medium (2 vCPU, 4 GB): ~$0.034
- n2-standard-8 (8 vCPU, 32 GB): ~$0.388
- c3-standard-8 (8 vCPU, 32 GB): ~$0.408
- a2-highgpu-1g (12 vCPU, 85 GB, 1xA100): ~$3.67

### Sustained Use Discounts (SUDs)

Automatic discount, no commitment needed:
- 0-25% monthly usage: full price
- 25-50%: 20% off
- 50-75%: 40% off
- 75-100%: 60% off
- **Effective discount for 100% usage: ~30%**
- Applies to N1, N2, N2D, C2. NOT E2, Tau, A2, A3 (already optimized pricing).
- SUDs + CUDs do not stack. CUDs replace SUDs for committed resources.

### Committed Use Discounts (CUDs)

| Term | Discount |
|------|----------|
| 1-year | Up to 57% |
| 3-year | Up to 70% |

- **Resource-based CUDs:** Commit to vCPU and memory quantities. Applies across project/region regardless of instance type.
- **Spend-based CUDs:** Commit to hourly spend for GPUs and local SSDs.
- CUD sharing across projects within billing account (must enable).

### Spot VMs

60-91% discount on spare capacity. No max lifetime (unlike legacy preemptible).
- 30-second reclaim warning. No SLA, no live migration.
- Best for: batch, CI/CD, data processing, fault-tolerant workloads.

### Live Migration

GCP transparently migrates VMs during host maintenance. Sub-second network blip. No downtime for host OS updates, hardware repairs, security patches. Default behavior -- unique to GCP.

### Sole-Tenant Nodes

Dedicated physical servers for compliance, BYOL (Windows/Oracle), isolation. Per-node pricing with ability to overcommit.

### Rightsizing Recommender

Analyzes last 8 days of utilization. Recommendations: resize, change type, stop idle instances. Cost impact estimates included.

---

## 2. Cloud Run (Serverless Containers)

### What Makes Cloud Run Unique

Full OCI containers on fully managed serverless. No cluster, no node pools, no K8s YAML. Deploy a container, get an HTTPS endpoint. GCP's strongest serverless differentiator.

### Execution Models

- **Services:** Long-running, request-driven. HTTP/1.1, HTTP/2, gRPC, WebSockets.
- **Jobs:** Batch/task execution, run to completion. Array jobs for parallel processing.

### Concurrency Model (Major Differentiator)

Single instance handles up to **1000 concurrent requests** (configurable 1-1000).
- vs AWS Lambda: strictly 1 invocation per instance.
- Amortizes cold start cost across many requests. Dramatically lower cost for high throughput.
- Set concurrency=1 only when code is not thread-safe.

### Pricing (per-second, 100ms minimum)

- vCPU: $0.0000240/vCPU-second
- Memory: $0.0000025/GiB-second
- Requests: $0.40/million
- Free tier: 2M requests, 360K GiB-seconds, 180K vCPU-seconds/month

### CPU Allocation Modes

- **Request-based (default):** CPU allocated only during request processing. Cheapest for intermittent traffic. Container frozen between requests.
- **Always-on CPU:** CPU always allocated. Required for background processing, WebSockets. ~2.5x per-second rate.

### Scaling

- **Min instances:** Keep N warm (eliminates cold starts, costs for idle).
- **Max instances:** Hard cap (cost protection).
- **Startup CPU boost:** Extra CPU during startup for heavy frameworks.
- Typical cold start: 200ms-2s.

### When to Choose Cloud Run

- vs Cloud Functions: custom runtimes, larger instances, concurrency, long connections, portable containers.
- vs GKE: zero ops, stateless request-driven. GKE for stateful, GPU, complex networking.
- vs App Engine: Cloud Run is the modern replacement.

---

## 3. Cloud Functions (FaaS)

### 1st Gen vs 2nd Gen

| Capability | 1st Gen | 2nd Gen (built on Cloud Run) |
|------------|---------|------------------------------|
| Timeout | 9 min | 60 min (HTTP) |
| Instance size | 8 GB / 2 vCPU | 32 GB / 8 vCPU |
| Concurrency | 1 request/instance | Up to 1000/instance |
| Traffic splitting | No | Yes |
| Triggers | HTTP, Pub/Sub, GCS, Firestore | All of 1st gen + Eventarc (120+ types) |

**Always use 2nd Gen.** 1st Gen is legacy. 2nd Gen is Cloud Run under the hood.

Pricing: $0.40/M invocations + compute (same rates as Cloud Run). Free tier: 2M invocations, 400K GB-seconds.

---

## 4. Google Kubernetes Engine (GKE)

### Autopilot vs Standard

| Aspect | Autopilot | Standard |
|--------|-----------|----------|
| Node management | Google-managed | Self-managed |
| Pricing | Per-pod resource requests | Per-node (whole VMs) |
| Scaling | Automatic | Manual + autoscaler |
| Security | Hardened, no SSH | Full node access |
| GPU/TPU | Yes (Spot pods) | Yes (full control) |
| DaemonSets | Restricted | Full support |
| Cost at >80% utilization | More expensive | Cheaper |

### Autopilot Pricing

- vCPU: $0.0445/hr (regular), $0.0148/hr (Spot)
- Memory: $0.0049/GB-hr (regular), $0.0016/GB-hr (Spot)
- No cluster management fee.

### Standard Pricing

- Cluster management: $0.10/hr ($73/mo).
- Nodes: standard Compute Engine pricing.

### Cost Optimization

1. **Spot pods in Autopilot:** 60-91% savings for fault-tolerant workloads.
2. **CUDs apply** to GKE Standard node usage.
3. **GKE cost allocation:** Track costs per namespace, label, team.
4. **Cluster autoscaler + VPA:** Right-size pods and nodes.
5. **Node auto-provisioning:** Optimal VM sizes for pending pods.
6. **Multi-tenant clusters:** Share instead of one-cluster-per-team (save $73/mo per cluster).

### GKE Networking

- **Dataplane V2** (eBPF/Cilium): default for Autopilot.
- Gateway API support (native, multi-cluster).
- Multi-cluster Services (MCS) for cross-cluster discovery.
- GKE Ingress integrated with Cloud Load Balancing.

### GKE Enterprise (formerly Anthos)

Multi-cluster across GCP, on-prem, other clouds. Config Sync (GitOps), Policy Controller (OPA), Service Mesh (managed Istio). $0.01/vCPU-hour.

---

## 5. App Engine

- **Standard:** Auto-scales to zero, limited runtimes, sandbox, free daily quotas. Good for simple zero-ops apps.
- **Flexible:** Custom Docker containers on VMs, does NOT scale to zero (min 1 instance).
- **Guidance:** Standard still valid for simple HTTP apps with free tier. For everything else, prefer Cloud Run.
