# Azure Database Reference

> Prices are US East, pay-as-you-go unless noted. Verify at https://azure.microsoft.com/pricing/.

## 1. Azure SQL Database

Fully managed SQL Server engine. Two purchasing models with very different economics.

### DTU Model

DTU bundles compute, memory, and IO into a single metric:

| Tier | DTUs | Storage | $/month | Use Case |
|------|------|---------|---------|----------|
| Basic | 5 | 2 GB | $4.99 | Tiny dev databases |
| Standard S0 | 10 | 250 GB | $14.72 | Light workloads |
| Standard S1 | 20 | 250 GB | $29.43 | Small production |
| Standard S3 | 100 | 1 TB | $147.02 | Moderate workloads |
| Premium P1 | 125 | 1 TB | $460.80 | IO-intensive, in-memory OLTP |
| Premium P4 | 500 | 1 TB | $1,843.20 | High concurrency, mission-critical |

Simpler but inflexible -- cannot independently scale compute vs storage. Best for steady, predictable workloads.

### vCore Model

Independent scaling of compute, storage, and memory:

| Tier | RAM/vCore | $/vCore/mo | Storage $/GB/mo | Key Feature |
|------|-----------|------------|-----------------|-------------|
| General Purpose | ~5.1 GB | ~$183 | $0.115 | Standard production |
| Business Critical | ~5.1 GB | ~$548 | included (4 TB max) | Built-in HA replicas, in-memory OLTP |
| Hyperscale | ~5.1 GB | ~$306 | $0.25 | 100 TB, instant scale, cheap replicas |

Reserved capacity: 1-year ~20% savings, 3-year ~40% savings.

### Hyperscale

The most versatile tier for production:

- **100 TB** maximum database size (vs 4 TB for General Purpose).
- **Instant scale-up:** Compute scales in seconds via pre-provisioned page server caches.
- **Rapid backup/restore:** Near-instantaneous backups. Any-size restore in minutes.
- **Named replicas:** Read-only replicas at ~30% of primary compute cost. Up to 30 per database.
- Free 10-day backup retention. Extended retention $0.10/GB/month.
- One-way migration: Hyperscale cannot move back to General Purpose.

### Serverless Compute

Available in General Purpose and Hyperscale tiers:

- **Auto-pause:** Pauses after configurable inactivity (min 1 hour). Pay only for storage while paused (~$0.115/GB/mo for GP).
- **Auto-resume:** First connection triggers resume. Cold start 30-60 seconds.
- **Auto-scale:** vCores scale between min (0.5) and max based on workload.
- ~40% premium per vCore-second vs provisioned, but pay only for active seconds.

**Break-even:** Serverless is cheaper when database is active <60-70% of the time. Always start with serverless for dev/test/staging.

### Elastic Pools

Share resources across multiple databases:

- DTU or vCore pools. Each database bursts to pool maximum.
- **Sweet spot:** 10+ databases with staggered peaks.
- Cost example: 20 databases each needing S2 (50 DTU) = $1,472/mo. If peak concurrency is 5 databases, 200 eDTU pool = $294/mo. Savings: 80%.
- Hyperscale elastic pools: up to 25 databases per pool. Good for SaaS per-tenant databases.

### Managed Instance

Near-100% SQL Server compatibility in a managed PaaS:

- **VNet-native**, cross-database queries, SQL Agent, CLR, linked servers, Service Broker.
- Pricing starts at ~$350/mo (4 vCores GP). Business Critical 8 vCores ~$2,700/mo.
- Use only when you need SQL Server features not in Azure SQL Database. Baseline cost is significantly higher.

### Azure SQL Cost Optimization

| Strategy | Savings | When |
|---|---|---|
| Serverless auto-pause (dev/test) | 50-80% | All non-production databases |
| Reserved capacity 1-year | ~20% | Stable production |
| Reserved capacity 3-year | ~40% | Long-term committed workloads |
| Azure Hybrid Benefit (SQL Server) | Up to 85% | Existing SQL Server licenses |
| Elastic Pools | 50-80% | SaaS with 10+ variable-load databases |
| Hyperscale named replicas | 70% vs full replicas | Read-scale workloads |
| Right-size vCores | Variable | Avg CPU <30% over 14 days |

**Monitoring:** `sys.dm_db_resource_stats` (15-second granularity), `cpu_percent`/`dtu_consumption_percent` metrics. Alert at 80%.

---

## 2. Cosmos DB

Globally distributed, multi-model database with guaranteed single-digit millisecond latency.

### Request Unit (RU) Model

All operations measured in Request Units. 1 RU = read a single 1 KB item by ID + partition key.

| Operation | Approximate RU Cost |
|-----------|-------------------|
| Point read (1 KB) | 1 RU |
| Point read (8 KB) | ~4 RU |
| Write (1 KB) | ~6 RU |
| Write (8 KB) | ~24 RU |
| Query returning 5 items (1 KB, indexed) | ~3-5 RU |
| Cross-partition query | 3-10x single-partition |

### Capacity Modes

| Mode | Min RU/s | $/100 RU/s/hr | Reserved 1yr | Use Case |
|------|----------|---------------|-------------|----------|
| **Provisioned** | 400 | $0.008 | $0.0048 (40% off) | Predictable, sustained |
| **Autoscale** | 10% of max | $0.012 | $0.0072 (40% off) | Variable with known peaks |
| **Serverless** | N/A | $0.282/M RUs | Not available | Dev/test, low/intermittent |

Cost example (10,000 RU/s sustained):
- Provisioned: $584/mo
- Provisioned + 1-year reserved: ~$350/mo
- Autoscale (max 10K, 60% avg utilization): ~$525/mo

### Global Distribution

- Each additional region multiplies RU/s cost. 3-region = 3x cost.
- **Multi-region write:** Each region accepts writes. Last-writer-wins conflict resolution.
- **Single-region write + multi-region read:** Cheaper. Reads scale with replicas.

### Consistency Levels

| Level | Read Cost | Guarantee |
|-------|----------|-----------|
| Strong | 2x RU | Linearizability (latest write) |
| Bounded Staleness | 2x RU | Reads lag by at most K versions or T time |
| Session | 1x RU | Read-your-own-writes (default, correct for 90%+ apps) |
| Consistent Prefix | 1x RU | No out-of-order reads |
| Eventual | 1x RU | No ordering guarantees |

Strong consistency doubles read RU cost and requires multi-region write disabled. Use only for financial/legal requirements.

### Partition Key Selection

The most critical design decision. Bad keys cannot be fixed without migration.

**Good keys:** High cardinality (`userId`, `deviceId`, `orderId`), even distribution, included in most queries.

**Bad keys:** Low cardinality (status codes, booleans), hot partitions (timestamps, sequential IDs), keys not in queries.

Hierarchical partition keys (`/tenantId/userId`) help multi-tenant scenarios exceeding the 20 GB logical partition limit.

### Change Feed

Ordered, persistent log of inserts and updates:
- Powers event-driven architectures -- trigger Functions, stream to Event Hubs, maintain materialized views.
- Does not capture deletes by default. Use soft-delete or "all versions and deletes" mode.

### Cosmos DB vs Azure SQL

| Factor | Cosmos DB | Azure SQL |
|--------|----------|-----------|
| Scale | >10K transactions/sec, global | Moderate, single-region |
| Data model | Schema-flexible, document/graph | Relational, complex joins |
| Consistency | Tunable, eventual acceptable | Strong required |
| Latency | <10ms p99 globally | <10ms single region |
| Cost at scale | Predictable via RU/s | Can be cheaper for moderate workloads |

---

## 3. Azure Cache for Redis

### Tiers

| Tier | Memory | Starting $/mo | Use Case |
|------|--------|--------------|----------|
| Basic C0 | 250 MB | $16 | Dev/test only (no SLA, no replication) |
| Standard C0 | 250 MB | $40 | Small production cache |
| Standard C3 | 13 GB | $263 | Production cache |
| Premium P1 | 6 GB | $418 | Clustering, VNet, geo-rep, persistence |
| Premium P4 | 53 GB | $3,341 | Large-scale (up to 10 shards) |
| Enterprise E10 | 12 GB | ~$579 | RedisJSON, RediSearch, RedisTimeSeries |
| Enterprise Flash E10 | 12 GB + 384 GB Flash | ~$579 | Cost-effective large caches |

### Selection Strategy

- **Basic:** Dev/test only. No replication, no SLA.
- **Standard:** Minimum for production. Automatic replication. 99.9% SLA.
- **Premium:** When you need VNet integration, clustering, persistence, or geo-replication.
- **Enterprise:** For Redis modules (RediSearch, RedisJSON) or Active-Active multi-region writes.
- **Enterprise Flash:** Large caches (hundreds of GB) cost-effectively. Hot data in RAM, warm on NVMe. 60-80% cheaper per GB than Enterprise RAM-only.

### Redis Cost Traps

- **Premium for VNet when Standard + Private Endpoint works:** Private Endpoint = $7.30/mo vs Premium P1 = $418/mo.
- **Over-sharding:** Each shard multiplies base price. 10-shard P4 = $33,408/mo. Start with 1 shard.
- **Caching everything:** Only cache hot data with appropriate TTLs. Cold data wastes expensive memory.

### Monitoring for Right-Sizing

- `cachehits`/`cachemisses`: Target >95% hit ratio.
- `usedmemory` vs `maxmemory`: Consistently <30% = downsize.
- `connectedclients`: Below tier limit = may not need higher tier.
- `serverload`: Consistently >80% = scale up or add shards.
