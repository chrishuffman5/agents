# AWS Database Reference

> RDS, Aurora, DynamoDB, ElastiCache, MemoryDB. Prices are US East (N. Virginia) on-demand.

---

## Database Selection Framework

```
Structured data + complex queries + transactions?
  -> RDS or Aurora (Section 1-2)
Key-value lookups at massive scale, single-digit ms?
  -> DynamoDB (Section 3)
Document storage with MongoDB compatibility?
  -> DocumentDB ($0.20/GB-mo storage, instance-based compute)
Caching, session store, real-time analytics?
  -> ElastiCache / MemoryDB (Section 4)
Relationship traversal, knowledge graphs?
  -> Neptune ($0.10/GB-mo, from $0.348/hr)
Time-series: IoT metrics, application telemetry?
  -> Timestream ($0.50/GB write, $0.01/GB query, $0.03/GB-mo storage)
Full-text search + analytics?
  -> OpenSearch Service (instance-based, from $0.084/hr for t3.small)
Data warehouse at petabyte scale?
  -> Redshift
```

### Managed vs Self-Managed Cost Comparison

**PostgreSQL: db.r6g.xlarge equivalent, 500 GB, Multi-AZ:**

| Factor | EC2 Self-Managed | RDS PostgreSQL | Aurora PostgreSQL |
|--------|-----------------|----------------|-------------------|
| Compute | $145/mo | $274/mo | $331/mo |
| Storage 500 GB | $40/mo (gp3) | $57.50/mo (gp3) | $50/mo (auto-scale) |
| Multi-AZ | Manual (2x compute) | +$274/mo (standby) | Included (6-way replication) |
| Backups | Manual scripting | Included (35-day) | Included (35-day) |
| **Total (Multi-AZ)** | **~$590/mo + ops** | **~$606/mo** | **~$381/mo** |

Aurora's 6-way replication provides Multi-AZ durability without a standby instance, making it cheaper than RDS Multi-AZ for production.

---

## 1. RDS vs Aurora

### Choose RDS When

- Small/dev workloads where Aurora's minimum ($0.073/hr for db.t4g.medium) is overkill
- Specific engine version not yet on Aurora
- Budget is primary constraint and Multi-AZ not needed

### Choose Aurora When

- Production workloads requiring high availability (6-way replication included)
- Read-heavy workloads (up to 15 read replicas, <10 ms lag)
- Workloads exceeding single-instance I/O (Aurora distributes writes)
- Need auto-scaling storage (10 GB - 128 TB, no pre-provisioning)
- Global Database needed (<1s cross-region replication)

### Instance Strategy

- **Graviton (r7g, r6g, m7g) = 20% savings:** db.r7g.xlarge at $0.437/hr vs db.r7i.xlarge at $0.548/hr
- **Burstable (t4g) for dev/test only:** $0.032/hr for db.t4g.micro. Never production.
- Use Performance Insights (free 7-day retention) to validate. Watch CPU >60% sustained or buffer pool hit ratio <95%.

### RDS Reserved Instance Pricing

| Term | Payment | Discount | Break-Even |
|------|---------|----------|------------|
| 1-year All Upfront | 100% now | ~40% | ~7 months |
| 1-year No Upfront | Monthly | ~30% | ~9 months |
| 3-year All Upfront | 100% now | ~60% | ~15 months |

**Cost example (db.r6g.xlarge Aurora, 1 year):** On-demand: $4,030/yr. 1-year All Upfront: $2,418/yr (40% savings).

### Aurora Serverless v2

- Scales: 0.5 ACU to 128 ACU (1 ACU = ~2 GB RAM)
- Cost: $0.12/ACU-hour
- **Saves money when:** Variable workloads (busy 4 hr/day, idle 20 hr)
  - Provisioned db.r6g.xlarge: $11.04/day
  - Serverless v2 (4 ACU x 4hr + 0.5 ACU x 20hr): $3.12/day (72% savings)
- **Costs more when:** Sustained high throughput (4 ACU 24/7: $11.52/day vs $11.04)
- **Rule of thumb:** Serverless v2 wins at <40% average utilization of peak. Provisioned wins at >60% sustained.

### Storage and I/O Costs

**Aurora:** $0.10/GB-mo, auto-scales. I/O: $0.20/M I/O requests (Standard) or I/O-Optimized ($0.225/GB-mo, no per-I/O charge).

**I/O-Optimized breakpoint:** Switch when I/O exceeds 25% of total Aurora cost. For 100 GB database, that is >112M I/Os/month.

**RDS storage:** gp3 at $0.115/GB-mo (3,000 IOPS, 125 MBps included). io2 at $0.125/GB + $0.065/provisioned IOPS.

### Read Replicas

- Aurora: up to 15 replicas, share same storage volume (<10ms lag), reader endpoint auto-balances
- RDS non-Aurora: up to 5 replicas
- Each replica = full instance price. Use Aurora Auto Scaling (min 1, max based on load).
- Cross-region replicas for DR: $0.09/GB data transfer between regions.

---

## 2. DynamoDB

### Capacity Mode Decision

**On-Demand ($1.25/M writes, $0.25/M reads):**
- New tables with unknown traffic patterns
- Spiky/unpredictable workloads (>4x variation between peak and trough)
- Dev/test with sporadic usage
- Very low volume (<25 writes/sec, <100 reads/sec)

**Provisioned + Auto Scaling:**
- Production with understood patterns
- Sustained workload above ~25 writes/sec or ~100 reads/sec
- **5-7x cheaper than On-Demand at steady state**

### Cost Comparison at Steady 100 WCU / 500 RCU

| Mode | Monthly Cost |
|------|-------------|
| On-Demand | $648/mo ($324 writes + $324 reads) |
| Provisioned | $94.90/mo ($47.45 WCU + $47.45 RCU) |
| Provisioned + 1yr Reserved | ~$50-75/mo |

**Migration strategy:** Start On-Demand, observe 2 weeks via CloudWatch, switch to Provisioned with observed peak + 20% headroom.

### Access Pattern Cost Optimization

**Reads:**
- Eventually consistent reads cost 0.5 RCU per 4 KB (half of strongly consistent)
- Use eventually consistent by default. Strongly consistent only when stale data causes bugs.
- Query vs Scan: Query reads only matching items. Scan reads entire table. A 10 GB scan: 2,560,000 RCU = **$640 On-Demand per scan**.

**Writes:**
- 1 WCU = 1 write/sec for items up to 1 KB. A 5 KB item costs 5 WCU per write.
- Keep items small. Large blobs in S3, reference by key in DynamoDB.
- Transactional writes cost 2x. Use transactions only when needed.

### Secondary Indexes Cost Impact

**GSI (Global Secondary Index):**
- Each GSI consumes its own read/write capacity, separate from base table
- Every write changing an indexed attribute triggers a GSI write
- Table with 3 GSIs can cost up to 4x write cost (1 base + 3 GSI writes)
- **Optimize:** Sparse indexes, project only needed attributes (`KEYS_ONLY` vs `ALL`)

**LSI (Local Secondary Index):**
- Shares capacity with base table (no additional write cost)
- 10 GB partition limit across base + all LSIs
- Must be defined at table creation

### DAX (DynamoDB Accelerator)

- In-memory cache, microsecond read latency
- Pricing: $0.269/hr for dax.r5.large (3-node minimum = **$589/mo**)
- **Use when:** Read-heavy with microsecond latency needs and eventually consistent reads acceptable
- **Alternative:** Application-level caching with ElastiCache is more flexible and cheaper for simple patterns

### Global Tables

- Multi-region active-active replication
- Replicated writes cost 1.5x ($1.875/M on-demand)
- Storage billed per region. Cross-region transfer: $0.09/GB.
- A table with 100 WCU in 2 regions costs ~2.5x single-region.

---

## 3. ElastiCache / MemoryDB

### Service Selection

```
Need in-memory data store?
  Cache only (volatile) ────┬── Advanced data structures, pub/sub, Lua ── ElastiCache Redis
                            └── Simple key-value, multi-threaded ── ElastiCache Memcached
  Durable Redis (replace Redis+DB) ── MemoryDB for Redis
  Serverless (no capacity planning) ── ElastiCache Serverless / MemoryDB Serverless
```

### Pricing Comparison

| Service | Instance | Monthly Cost |
|---------|----------|-------------|
| ElastiCache Redis | cache.r7g.large | $164.98 |
| ElastiCache Redis | cache.t4g.micro (dev/test) | $11.68 |
| MemoryDB Redis | db.r7g.large | $244.55 (48% more, adds durability) |
| ElastiCache Serverless | Variable | $0.0034/ECPU + $0.115/GB-mo |
| MemoryDB Serverless | Variable | $0.0044/ECPU + $0.365/GB-mo |

**Serverless break-even:** At ~40% sustained utilization of cache.r7g.large, provisioned becomes cheaper.

### Caching Strategies

| Strategy | How | Best For |
|----------|-----|----------|
| **Cache-Aside** | Read: check cache, miss -> read DB -> populate cache | General-purpose, user profiles, catalogs |
| **Write-Through** | Write: update cache + DB synchronously | Data read much more often than written |
| **Write-Behind** | Write: update cache, async batch-write DB | High write throughput, some data loss acceptable |

**TTL guidance:** Always set a TTL. 5-30s for cache-aside freshness. 3600s for slowly changing data. Even long TTLs (24h) prevent unbounded growth.

### Sizing

- **Cluster mode disabled:** Single shard, up to 5 replicas. Simpler. Max memory = single node.
- **Cluster mode enabled:** Multiple shards with replicas. Use when dataset >100 GB or write throughput exceeds single node.
- **Memory rule:** Allocate 2x dataset size (Redis overhead). Keep `DatabaseMemoryUsagePercentage` <80%.
