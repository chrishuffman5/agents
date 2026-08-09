# AWS Database Reference

> RDS, Aurora, DynamoDB, ElastiCache/MemoryDB, RDS Proxy, time-series and warehouse routing. Prices are US East (N. Virginia) and are PRICE-VOLATILE; quotas and mechanics are structural facts.
>
> Engine-level tuning (query plans, vacuum, index internals) belongs to the `database` plugin's per-engine skills. This file selects the service.

---

## Database Selection Framework

> Source: https://docs.aws.amazon.com/timestream/latest/developerguide/timestream-availability-update.html and https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-console-comparison.html (official)

```
Structured data + complex queries + transactions? -> RDS or Aurora (section 1)
Key-value at massive scale, single-digit ms?      -> DynamoDB (section 2)
Cache / session store / real-time structures?     -> ElastiCache (section 3)
Durable in-memory primary datastore?              -> MemoryDB (section 3)
MongoDB-compatible documents?                     -> DocumentDB
Graph traversal / knowledge graphs?               -> Neptune
Time-series?                                      -> Timestream for InfluxDB (see below)
Full-text search + log analytics?                 -> OpenSearch Service
Data warehouse?                                   -> Redshift Serverless (see below)
```

### Time-series: Timestream for LiveAnalytics is legacy

The original Timestream engine is now branded **Timestream for LiveAnalytics**, and AWS's own migration-guidance page actively steers customers off it:

- **Timestream for InfluxDB 3 Enterprise** — AWS's recommendation "for most LiveAnalytics migrations" and "any new greenfield deployment." Apache Arrow/DataFusion/Parquet on S3 object storage, unlimited cardinality, standard SQL plus InfluxQL, multi-node clusters up to 15 nodes.
- **Timestream for InfluxDB 2** — for low-latency operational monitoring under roughly 10 million series; single-instance or Multi-AZ, Flux/InfluxQL, single-digit-ms queries.
- Above 1M records/second ingestion, AWS suggests sharding across multiple InfluxDB 3 clusters, or DynamoDB for low-complexity analytics.

Do not quote LiveAnalytics' old per-GB write/query/storage rates as current time-series pricing — the InfluxDB-based replacements use a provisioned instance/cluster model instead.

### Warehouse: default to Redshift Serverless

AWS's own Serverless-vs-provisioned comparison documents the operational asymmetry: Serverless bills per-second in RPU-hours with a 60-second minimum, needs **no pause/resume** ("you pay only when queries run"), has **no maintenance window**, and replaces cluster resize with a base-RPU setting. **Provisioned clusters** remain right for steady 24/7 workloads that can commit to 1-3 year Reserved Instances, need concurrency-scaling controls, or need provisioned-only data-sharing modes (cross-Region, cross-account, AWS Data Exchange). Depth belongs to `database:redshift`.

---

## 1. RDS vs Aurora

> Source: https://aws.amazon.com/rds/features/read-replicas/ and https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.StorageReliability.html (official)

### Choose RDS when

- Small or dev workloads where Aurora's instance floor is overkill
- A specific engine version Aurora does not offer
- Budget is the binding constraint and Multi-AZ is not required

### Choose Aurora when

- Production high availability matters — Aurora's 6-way replication across 3 AZs provides Multi-AZ durability **without** paying for a standby instance, which is what often makes Aurora cheaper than RDS Multi-AZ in production
- Read-heavy workloads that benefit from **storage-layer replication with sub-10 ms replica lag**
- Storage growth is unpredictable — Aurora cluster volumes auto-scale to **256 TiB**
- Aurora Global Database is needed (typical cross-Region replication latency under a second; promotion of a secondary Region to read/write in under a minute)

### Read replicas — count is no longer the differentiator

**RDS for MySQL, PostgreSQL, MariaDB, and SQL Server now support up to 15 read replicas per DB instance** — the same ceiling as Aurora. **Only RDS for Oracle remains capped at 5.** Aurora still wins on replication *characteristics* (storage-layer replication, <10 ms lag, reader endpoint load balancing, no per-replica storage duplication) versus RDS's engine-native asynchronous replication with higher and more variable lag. Argue that, not the number.

Each replica bills as a full instance. Use Aurora Auto Scaling (min 1, scale on load) rather than standing replicas "just in case." Cross-Region replicas add inter-Region data transfer.

### Aurora Serverless v2

> Source: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.setting-capacity.html (official)

- **Capacity range is now 0 to 256 ACUs.** The minimum can be set to **0 ACUs, enabling automatic pause and resume** — the database stops billing compute when fully idle and resumes on connection (with a resume delay). The old 0.5 ACU floor is no longer the limit.
- **1 ACU is approximately 2 GiB of memory** (confirmed verbatim).
- Feature floors worth knowing before setting a minimum: AWS recommends **at least 2 ACUs for Performance Insights** and **at least 8 ACUs for an Aurora Global Database primary Region**.
- **Selection rule:** Serverless v2 wins on variable workloads well below sustained peak utilization, and now also on dev/test and intermittent workloads that can tolerate a resume delay (scale-to-zero). Provisioned wins on sustained high utilization.

### Storage and I/O

**Aurora I/O-Optimized breakpoint, quoted:** "Aurora I/O-Optimized is the best choice when your I/O spending is 25% or more of your total Aurora database spending." Standard mode bills per million I/O requests; I/O-Optimized removes the per-I/O charge in exchange for a higher storage rate.

Operational detail that matters for change planning: you can switch Standard -> I/O-Optimized **once every 30 days**. For non-NVMe instances — which includes all Aurora Serverless instances — the switch is **zero-downtime**; NVMe-backed provisioned instances require an engine restart.

### RDS Proxy

> Source: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy.html (official)

"By using Amazon RDS Proxy, you can allow your applications to pool and share database connections to improve their ability to scale. RDS Proxy makes applications more resilient to database failures by automatically connecting to a standby DB instance while preserving application connections."

Reach for it when highly concurrent or bursty compute — Lambda being the canonical case — opens connections faster than the database can absorb them, risking max-connections exhaustion. Under overload the proxy queues or throttles, and sheds load by rejecting connections rather than overwhelming the database.

Constraints that shape the design: the proxy must sit **in the same VPC as the database**, is never itself publicly accessible, authenticates clients via IAM and reaches the database via IAM or Secrets Manager, and **targets a single DB instance and only the writer** — it is not a read-replica fan-out mechanism. Its decisive advantage in "least operational overhead" scenarios: "You can enable RDS Proxy for most applications with no code changes."

---

## 2. DynamoDB

> Source: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Limits.html and https://aws.amazon.com/about-aws/whats-new/2024/11/amazon-dynamo-db-reduces-prices-on-demand-throughput-global-tables (official)

### Capacity mode

**On-Demand** for new tables with unknown traffic, spiky workloads with more than ~4x peak-to-trough variation, dev/test, and genuinely low volume. **Provisioned + Auto Scaling** for production with understood patterns and sustained throughput.

Provisioned is still materially cheaper at steady state, but **size the claim against current prices**: AWS cut on-demand throughput prices by ~50% effective **November 1, 2024**. Older material citing an ~85% saving from switching is roughly 2x overstated; the current gap is closer to ~70%. Migration path is unchanged: start On-Demand, observe two weeks of CloudWatch `ConsumedWriteCapacityUnits`/`ConsumedReadCapacityUnits`, then switch to Provisioned at observed peak plus ~20% headroom.

### Access-pattern economics

- 1 WCU writes one item up to 1 KB per second; a 5 KB item costs 5 WCU per write. Keep items small — large blobs belong in S3 with a key reference in the table.
- Eventually consistent reads cost half a strongly consistent read. Default to eventually consistent; require a stated correctness reason for strong consistency.
- **Query reads only matching items; Scan reads the whole table.** A full-table Scan on a large table is one of the most expensive single operations in AWS. Design access patterns so Scan is never on the hot path.
- Transactional writes cost twice a normal write.

### Secondary indexes and quotas

- **LSI** — shares base-table capacity, must be defined at table creation, and the **10 GB partition limit spans the base table plus all LSIs**. Maximum **5 LSIs per table**.
- **GSI** — consumes its own read/write capacity; every write that changes an indexed attribute triggers a GSI write, so three GSIs can approach 4x the write cost. Default quota is **20 GSIs per table** (adjustable). Optimize with sparse indexes and `KEYS_ONLY` projections rather than `ALL`.
- **Vector indexes** are a newer capability: up to 5 per table, up to 4,096 dimensions per index, TopK up to 100 per `SearchVectors` request, one HASH partition key per vector index. Relevant to RAG/embedding workloads — route depth to `database:dynamodb`.
- Table quota: **2,500 tables per account per Region** by default (adjustable to 10,000) — a real ceiling for table-per-tenant designs.

### DAX and Global Tables

**DAX** delivers microsecond reads for read-heavy workloads that tolerate eventual consistency, with a three-node minimum that makes it an expensive floor. Application-level caching on ElastiCache is more flexible and cheaper for simple patterns.

**Global Tables** give multi-Region active-active replication with last-writer-wins reconciliation; replicated writes carry a premium and storage bills per Region, so a two-Region table costs meaningfully more than 2x a single-Region one once cross-Region transfer is counted.

---

## 3. ElastiCache and MemoryDB

> Source: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.html, https://aws.amazon.com/elasticache/, https://aws.amazon.com/elasticache/pricing/, https://docs.aws.amazon.com/memorydb/latest/devguide/what-is-memorydb.html, https://aws.amazon.com/memorydb/ (official)

### Engines: Valkey, Redis OSS, Memcached

ElastiCache's own documentation states plainly: "**Amazon ElastiCache works with the Valkey, Memcached, and Redis OSS engines.**" Supported versions: "ElastiCache Serverless is compatible with Valkey 7.2 and higher, Memcached 1.6.22 and above, and Redis OSS 7.1." MemoryDB states it "is compatible with the popular open source data stores **Valkey and Redis OSS**." AWS presents these as co-equal supported engines.

**Valkey is the cost-advantaged choice, confirmed on AWS's pricing page:**

- **ElastiCache Serverless for Valkey is priced ~33% lower** than Serverless for Redis OSS or Memcached.
- **Node-based ElastiCache for Valkey is priced ~20% lower** than node-based Redis OSS.
- **Serverless minimum metered data storage is 100 MB for Valkey, versus 1 GB for Redis OSS and Memcached** — a real difference for small, low-traffic caches.
- Node-based ElastiCache **Valkey clusters support an optional durability feature**: data is persisted to a distributed Multi-AZ transactional log so it survives a full cache-node failure, with replicas recovering independently without loading the primary. No stated Redis OSS or Memcached equivalent on ElastiCache.

**Recommendation:** default new ElastiCache and MemoryDB deployments to Valkey on cost and durability grounds; choose Redis OSS only for a hard Redis-specific dependency, and Memcached only for simple multi-threaded key-value caching with no data-structure or persistence requirement.

### Service selection

```
Need an in-memory data store?
  Volatile cache -+-- Rich data structures, pub/sub, scripting -- ElastiCache (Valkey preferred)
                  +-- Simple multi-threaded key-value ---------- ElastiCache for Memcached
  Durable primary datastore (replaces cache + database) -------- MemoryDB (Valkey or Redis OSS)
  No capacity planning wanted ---------------------------------- ElastiCache Serverless /
                                                                  MemoryDB Serverless
```

MemoryDB costs more than ElastiCache for equivalent node classes because it adds durability — pay that premium only when the in-memory store is the system of record.

### Caching strategies

| Strategy | Mechanic | Best for |
|---|---|---|
| Cache-aside | Read: check cache, on miss read DB and populate | General purpose — user profiles, catalogs |
| Write-through | Write: update cache and DB synchronously | Data read far more often than written |
| Write-behind | Write: update cache, batch to DB asynchronously | High write throughput tolerating some loss |

**Always set a TTL**, even a long one — it bounds memory growth and staleness. Seconds for freshness-sensitive cache-aside; an hour or more for slowly changing reference data.

### Sizing

Cluster mode disabled = a single shard with replicas; maximum dataset is one node's memory. Cluster mode enabled = multiple shards, needed once the dataset or write throughput exceeds a single node. Allocate roughly twice the dataset size for engine overhead and keep memory utilization below ~80%.

## Sources

- https://docs.aws.amazon.com/timestream/latest/developerguide/timestream-availability-update.html
- https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-console-comparison.html
- https://aws.amazon.com/rds/features/read-replicas/
- https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.StorageReliability.html
- https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.setting-capacity.html
- https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy.html
- https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Limits.html
- https://aws.amazon.com/about-aws/whats-new/2024/11/amazon-dynamo-db-reduces-prices-on-demand-throughput-global-tables
- https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.html
- https://aws.amazon.com/elasticache/
- https://aws.amazon.com/elasticache/pricing/
- https://docs.aws.amazon.com/memorydb/latest/devguide/what-is-memorydb.html
- https://aws.amazon.com/memorydb/

Fetched: 2026-08-08
