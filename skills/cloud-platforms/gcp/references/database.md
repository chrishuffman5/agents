# GCP Database Reference

> Prices are us-central1 unless noted. Verify at https://cloud.google.com/pricing.

## 1. BigQuery (Serverless Data Warehouse)

GCP's strongest strategic asset. Fully serverless -- no clusters, no nodes, no indexes. Google's Dremel engine. Scales from bytes to petabytes.

### Pricing Models

| Model | Cost | Best For |
|-------|------|----------|
| On-Demand | $6.25/TB scanned | Sporadic/unpredictable queries |
| Standard Edition | $0.04/slot-hour (autoscale) | Steady workloads, no commitment |
| Enterprise Edition | $0.06/slot-hour | HA, CMEK, cross-region replication |
| Enterprise Plus | $0.10/slot-hour | Advanced ML, compliance |
| CUD (1yr) | ~37% off edition pricing | Predictable analytics |
| CUD (3yr) | ~55% off edition pricing | Long-term commitment |

**Slots:** A slot = virtual CPU + memory. Autoscaling editions: baseline 0, scale automatically, billed per slot-second. Reservations guarantee minimum slots; idle slots shared if enabled.

### Cost Optimization (Critical)

1. **Partitioning:** By date/timestamp. Queries scan only relevant partitions. 90%+ scan reduction. Always partition large tables.
2. **Clustering:** Sort within partitions by 4 frequently-filtered columns. Combine: partition on date, cluster on customer_id, region.
3. **SELECT only needed columns.** BigQuery is columnar -- SELECT * scans every column.
4. **Dry run:** `--dry_run` estimates bytes before execution. Use in CI/CD.
5. **Limit bytes billed:** `maximum_bytes_billed` fails queries exceeding threshold.
6. **Materialized views:** Pre-computed, auto-refreshed. Queries auto-rewrite to use them.
7. **BI Engine:** In-memory acceleration ($30.40/GB/month) for sub-second dashboards.
8. **Batch vs streaming loads:** Streaming $0.05/GB vs batch from GCS free. Always batch when latency allows.

### Storage Pricing

- Active: $0.020/GB/month
- Long-term (90+ days unmodified): $0.010/GB/month (automatic, free transition)

### BigQuery ML

Train models with SQL: `CREATE MODEL ... OPTIONS(model_type='logistic_reg')`
- Models: linear/logistic regression, k-means, ARIMA_PLUS, DNN, boosted trees, AutoML Tables, imported TF/ONNX.
- Inference: `ML.PREDICT()` runs in-warehouse without data export.
- Eliminates export -> train -> import pipeline for SQL teams.

### Key Features

- Federated queries: Cloud Storage, Cloud SQL, Spanner, Bigtable.
- Data Transfer Service: scheduled imports from SaaS (Google Ads, S3, Teradata).
- BigLake: unified governance across BigQuery and data lake.
- Analytics Hub: cross-org data sharing.
- Multi-statement ACID transactions.

---

## 2. Cloud SQL (Managed RDBMS)

### Supported Engines

MySQL (5.7, 8.0), PostgreSQL (12-17), SQL Server (2017-2022).

### Editions

- **Enterprise:** Standard HA, up to 96 vCPU / 624 GB RAM. 99.95% SLA.
- **Enterprise Plus:** 99.99% SLA, data cache (SSD), up to 128 vCPU / 864 GB RAM, advanced DR.

### Pricing

- Instance: db-f1-micro (~$7.67/mo) to db-custom-96 (~$4,800/mo).
- Storage: SSD $0.170/GB/mo, HDD $0.090/GB/mo.
- HA: doubles instance + storage cost (synchronous standby).
- Read replicas: same pricing as primary.
- Backups: $0.08/GB/month.

### Cloud SQL Auth Proxy

Secure IAM-authenticated connection without IP allowlists or SSL cert management. Runs as sidecar (great with Cloud Run, GKE).

### When Cloud SQL vs Alternatives

- vs AlloyDB: choose AlloyDB for PostgreSQL needing 4x throughput + analytical queries.
- vs Spanner: choose Spanner for global distribution + horizontal scale.
- vs self-managed on GCE: choose Cloud SQL for managed ops. Self-managed for unsupported configs.

---

## 3. AlloyDB for PostgreSQL

Google-built storage engine, PostgreSQL-compatible:
- **4x faster** than standard PostgreSQL for transactional. **100x faster** for analytical queries.
- Columnar engine for analytical acceleration (automatic).
- AI/ML: vector embeddings, ML predictions via SQL with Vertex AI.
- Pricing: vCPU $0.1386/hr, memory $0.0156/GB/hr, storage $0.0005/GB/hr.
- HA included (primary + standby in different zones).

**When AlloyDB:** PostgreSQL workloads needing high performance, mixed OLTP/OLAP, or vector search.

---

## 4. Cloud Spanner (Globally Distributed Relational)

**What makes Spanner unique:** Strongly consistent, globally distributed relational database. TrueTime (GPS + atomic clocks) enables external consistency across continents. No other cloud database offers this.

### Architecture

- Processing units (PU): 1 node = 1000 PU. Each node: ~10K reads/sec or ~2K writes/sec.
- Horizontal scaling: add nodes for linear throughput increase.
- Auto-sharding by primary key.

### Pricing

| Config | Node Cost/mo | Storage $/GB/mo |
|--------|-------------|----------------|
| Regional | ~$657 | $0.30 |
| Multi-region | ~$1,971 | $0.50 |

Minimum cost: ~$657/month (one regional node).

### When Spanner

- Need global strong consistency (financial transactions, inventory).
- Need 99.999% availability (five 9s, multi-region).
- Need relational model with unlimited horizontal scale.
- Can justify the minimum cost.
- **NOT for:** Small apps, cost-sensitive workloads, simple key-value.

Interfaces: GoogleSQL (richer) and PostgreSQL (compatibility mode).

---

## 5. Firestore (Document Database)

### Two Modes (choose at creation, cannot switch)

- **Native mode:** Real-time listeners, offline support, mobile/web SDKs. For mobile/web apps.
- **Datastore mode:** Server-side only, no real-time. For server apps, batch processing.

### Pricing (per-operation)

- Reads: $0.06/100K
- Writes: $0.18/100K
- Deletes: $0.02/100K
- Storage: $0.18/GB/month

**Free tier per day:** 50K reads, 20K writes, 20K deletes, 1 GB storage.

### Key Features

- Strong consistency for all reads.
- Multi-region replication (automatic).
- TTL policies for automatic document deletion.
- Security rules (client-side access control) in Native mode.

---

## 6. Bigtable (Wide-Column NoSQL)

- Managed HBase-compatible wide-column store.
- Single-digit millisecond latency at any scale.
- Minimum 1 node/cluster (~$0.65/hr = ~$468/mo).
- Storage: SSD $0.026/GB/mo, HDD $0.012/GB/mo.
- Autoscaling by CPU/storage utilization.
- For: time-series, IoT telemetry, financial data, ML feature stores.
- Not for ad-hoc analytics (use BigQuery).

---

## 7. Memorystore (Managed Redis/Memcached/Valkey)

- Redis: 1-300 GB. Standard (HA) or Basic (no HA).
- Memcached: up to 5 TB.
- Valkey: Redis-compatible, open-source (post-Redis licensing change).
- Pricing: $0.016-0.049/GB/hr.
- For: caching, session storage, leaderboards, real-time analytics.

---

## 8. Database Decision Matrix

| Need | Choose |
|------|--------|
| Analytics warehouse | BigQuery (always) |
| Relational, managed, single-region | Cloud SQL |
| Relational, high-perf PostgreSQL | AlloyDB |
| Relational, global distribution | Spanner |
| Document, mobile/web, real-time | Firestore (Native) |
| Wide-column, time-series, IoT | Bigtable |
| In-memory cache | Memorystore |
