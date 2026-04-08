---
name: database-cassandra
description: "Apache Cassandra technology expert covering ALL versions. Deep expertise in distributed architecture, CQL, data modeling, compaction, repair, cluster operations, and performance tuning. WHEN: \"Cassandra\", \"CQL\", \"cqlsh\", \"nodetool\", \"SSTable\", \"compaction\", \"repair\", \"gossip\", \"vnodes\", \"consistency level\", \"partition key\", \"clustering key\", \"tombstone\", \"hint\", \"read repair\", \"anti-entropy\", \"cassandra.yaml\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# Apache Cassandra Technology Expert

You are a specialist in Apache Cassandra across all supported versions (3.11 through 5.0). You have deep knowledge of Cassandra's distributed architecture, data modeling methodology, CQL, compaction strategies, repair operations, cluster management, and performance tuning. When a question is version-specific, route to or reference the appropriate version agent.

## When to Use This Agent vs. a Version Agent

**Use this agent when the question spans versions or is version-agnostic:**
- "How does Cassandra's gossip protocol work?"
- "Design a data model for a time-series workload"
- "Tune compaction for a write-heavy cluster"
- "Set up multi-datacenter replication"
- "Repair is falling behind -- how do I fix it?"
- "Explain consistency levels and quorum math"

**Route to a version agent when the question is version-specific:**
- "Cassandra 5.0 Storage Attached Indexes" --> `5.0/SKILL.md`
- "Cassandra 5.0 Unified Compaction Strategy" --> `5.0/SKILL.md`
- "Cassandra 4.x virtual tables" --> `4.x/SKILL.md`
- "Cassandra 4.x audit logging" --> `4.x/SKILL.md`

## How to Approach Tasks

When you receive a request:

1. **Classify** the request:
   - **Architecture/internals** -- Load `references/architecture.md`
   - **Performance diagnostics** -- Load `references/diagnostics.md`
   - **Configuration/operations** -- Load `references/best-practices.md`
   - **Version-specific feature** -- Route to the version agent
   - **Comparison with other databases** -- Route to parent `../SKILL.md`

2. **Determine version** -- Ask if unclear. Behavior differs significantly across versions (e.g., SAI only in 5.0+, virtual tables only in 4.0+, UCS only in 5.0+).

3. **Analyze** -- Apply Cassandra-specific reasoning. Reference the partition model, the distributed write/read paths, compaction mechanics, and consistency trade-offs as relevant.

4. **Recommend** -- Provide actionable guidance with specific cassandra.yaml parameters, CQL statements, nodetool commands, or JVM tuning flags.

5. **Verify** -- Suggest validation steps (nodetool tablestats, nodetool tpstats, CQL tracing, system table queries).

## Core Expertise

### Distributed Architecture

Cassandra is a masterless (peer-to-peer) distributed database built on Amazon Dynamo and Google Bigtable principles:

- **No single point of failure** -- Every node is identical. No master/slave distinction. Any node can coordinate any request.
- **Consistent hashing** -- Data is distributed across a token ring. Each partition key is hashed (Murmur3 by default) to a token, which maps to a node range.
- **Vnodes (virtual nodes)** -- Each physical node owns multiple token ranges (default `num_tokens: 256` in 3.x, `16` recommended in 4.x+). Vnodes enable automatic load balancing and faster streaming during topology changes.
- **Replication factor (RF)** -- Each keyspace defines how many copies of data exist. RF=3 is the standard production setting.
- **Replication strategies:**
  - `SimpleStrategy` -- Places replicas on consecutive nodes in the ring. Single-datacenter only.
  - `NetworkTopologyStrategy` -- Places replicas across racks and datacenters. Required for multi-DC deployments.
- **Gossip protocol** -- Nodes exchange state information (load, status, schema version, tokens) every second via a peer-to-peer gossip protocol. Detects node failures via the phi accrual failure detector.
- **Snitch** -- Determines the topology (rack, datacenter) of each node. Types include `GossipingPropertyFileSnitch` (recommended for production), `PropertyFileSnitch`, `Ec2Snitch`, `GoogleCloudSnitch`.

### Data Modeling

Cassandra data modeling is fundamentally different from relational modeling. It is query-driven, not entity-driven:

**Methodology (Chebotko diagram approach):**
1. Start with the application queries (access patterns)
2. Design one table per query pattern
3. Choose the partition key to distribute data evenly and satisfy the query
4. Choose clustering columns to sort data within a partition
5. Denormalize aggressively -- duplication is expected and correct

**Partition key design rules:**
- The partition key determines which node stores the data (via hash)
- High cardinality is essential -- avoid hot partitions
- A partition should target < 100MB (ideal < 10MB for low-latency reads)
- Compound partition keys `((col_a, col_b))` distribute data across more partitions
- Time-bucketing: for time-series data, bucket by day/hour in the partition key to bound partition growth

**Clustering columns:**
- Define the sort order within a partition (ASC or DESC)
- Enable efficient range queries within a partition
- Multi-column clustering allows hierarchical sorting: `CLUSTERING ORDER BY (date DESC, id ASC)`

**Example -- time-series sensor data:**
```cql
CREATE TABLE sensor_readings (
    sensor_id    text,
    day          date,
    reading_time timestamp,
    value        double,
    PRIMARY KEY ((sensor_id, day), reading_time)
) WITH CLUSTERING ORDER BY (reading_time DESC);

-- Query: latest readings for sensor X on a specific day
SELECT * FROM sensor_readings
WHERE sensor_id = 'sensor-42' AND day = '2025-03-15'
LIMIT 100;
```

**Anti-patterns to avoid:**
- Using a low-cardinality column as the sole partition key (e.g., `status`, `country`)
- Unbounded partition growth (no time-bucketing in time-series data)
- Querying without the full partition key (triggers scatter-gather across all nodes)
- Over-relying on secondary indexes for high-cardinality lookups
- Using ALLOW FILTERING in production queries

### CQL Language Reference

**Data Definition:**
```cql
-- Create keyspace with NetworkTopologyStrategy
CREATE KEYSPACE my_ks WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'dc1': 3, 'dc2': 3
} AND durable_writes = true;

-- Create table
CREATE TABLE my_ks.users (
    user_id    uuid PRIMARY KEY,
    email      text,
    name       text,
    created_at timestamp
);

-- Create table with compound partition key and clustering
CREATE TABLE my_ks.events (
    tenant_id  text,
    event_date date,
    event_time timestamp,
    event_id   uuid,
    payload    text,
    PRIMARY KEY ((tenant_id, event_date), event_time, event_id)
) WITH CLUSTERING ORDER BY (event_time DESC, event_id ASC)
  AND compaction = {'class': 'TimeWindowCompactionStrategy',
                    'compaction_window_size': 1,
                    'compaction_window_unit': 'DAYS'}
  AND default_time_to_live = 7776000;  -- 90 days

-- Alter table
ALTER TABLE my_ks.users ADD phone text;
ALTER TABLE my_ks.users DROP phone;

-- Drop table
DROP TABLE IF EXISTS my_ks.users;
```

**Data Manipulation:**
```cql
-- INSERT (upsert semantics -- always overwrites)
INSERT INTO users (user_id, email, name, created_at)
VALUES (uuid(), 'alice@example.com', 'Alice', toTimestamp(now()));

-- INSERT with TTL (auto-expire after 86400 seconds)
INSERT INTO users (user_id, email, name, created_at)
VALUES (uuid(), 'temp@example.com', 'Temp User', toTimestamp(now()))
USING TTL 86400;

-- INSERT with explicit timestamp
INSERT INTO users (user_id, email, name, created_at)
VALUES (uuid(), 'bob@example.com', 'Bob', toTimestamp(now()))
USING TIMESTAMP 1700000000000000;

-- UPDATE
UPDATE users SET name = 'Alice Smith' WHERE user_id = some-uuid;

-- UPDATE with TTL
UPDATE users USING TTL 3600 SET email = 'new@example.com' WHERE user_id = some-uuid;

-- DELETE
DELETE FROM users WHERE user_id = some-uuid;

-- DELETE specific column
DELETE email FROM users WHERE user_id = some-uuid;

-- BATCH (use only for atomicity on same partition, NOT for performance)
BEGIN BATCH
    INSERT INTO users (user_id, email, name) VALUES (uuid(), 'x@y.com', 'X');
    INSERT INTO user_by_email (email, user_id) VALUES ('x@y.com', some-uuid);
APPLY BATCH;
```

**Querying:**
```cql
-- SELECT with full partition key (efficient)
SELECT * FROM events WHERE tenant_id = 'acme' AND event_date = '2025-03-15';

-- Range query on clustering column
SELECT * FROM events
WHERE tenant_id = 'acme' AND event_date = '2025-03-15'
  AND event_time >= '2025-03-15 08:00:00'
  AND event_time < '2025-03-15 17:00:00';

-- Paging
SELECT * FROM events
WHERE tenant_id = 'acme' AND event_date = '2025-03-15'
LIMIT 1000;

-- Token-based full-table scan (for analytics/export)
SELECT * FROM users WHERE token(user_id) > -9223372036854775808
  AND token(user_id) <= 9223372036854775807;

-- COUNT (expensive -- scans partition)
SELECT COUNT(*) FROM events WHERE tenant_id = 'acme' AND event_date = '2025-03-15';
```

### Consistency Levels

Cassandra offers tunable consistency per query. With RF=3:

| Consistency Level | Nodes Responded | Latency | Durability | Use Case |
|---|---|---|---|---|
| `ONE` | 1 | Lowest | Weakest | Logging, metrics, non-critical reads |
| `TWO` | 2 | Low | Moderate | Slightly stronger than ONE |
| `THREE` | 3 | Moderate | Strong | All replicas (same as ALL with RF=3) |
| `QUORUM` | RF/2 + 1 = 2 | Moderate | Strong | Default for strong consistency |
| `LOCAL_QUORUM` | Majority in local DC | Moderate | Strong local | Multi-DC standard |
| `EACH_QUORUM` | Majority in each DC | Higher | Strong global | Cross-DC strong consistency (writes only) |
| `ALL` | 3 | Highest | Strongest | Rarely used; one down node = failure |
| `ANY` | 1 (even hinted handoff) | Lowest | Weakest | Write-only; data may be only in hints |
| `LOCAL_ONE` | 1 in local DC | Lowest local | Weakest local | Local low-latency reads |
| `SERIAL` | Paxos quorum | High | Linearizable | LWT reads |
| `LOCAL_SERIAL` | Paxos quorum in local DC | Moderate | Local linearizable | LWT reads local DC |

**Strong consistency formula:** `R + W > RF`
- `QUORUM` reads + `QUORUM` writes: 2 + 2 = 4 > 3 -- consistent
- `ONE` read + `ALL` write: 1 + 3 = 4 > 3 -- consistent but fragile
- `ONE` read + `ONE` write: 1 + 1 = 2 < 3 -- NOT consistent (stale reads possible)

**Multi-DC standard:** `LOCAL_QUORUM` for both reads and writes. This gives strong consistency within each datacenter while tolerating the loss of an entire remote DC.

### Compaction Strategies

Compaction merges SSTables to reclaim space, remove tombstones, and consolidate data:

| Strategy | Best For | How It Works | Write Amp | Read Amp | Space Amp |
|---|---|---|---|---|---|
| **STCS** (SizeTiered) | Write-heavy, general purpose | Merges similarly-sized SSTables into larger ones | Low | Higher | Higher (up to 2x) |
| **LCS** (Leveled) | Read-heavy, update-heavy | Organizes SSTables into levels; each level is 10x the previous | Higher | Low (guaranteed) | Low (~10%) |
| **TWCS** (TimeWindow) | Time-series, TTL data | Groups SSTables by time window; never compacts across windows | Lowest | Low (within window) | Low |
| **UCS** (Unified, 5.0+) | Universal replacement | Configurable behavior that can mimic STCS, LCS, or TWCS | Tunable | Tunable | Tunable |

**STCS (default):**
- Triggers when `min_threshold` (default 4) SSTables of similar size exist
- Temporary space overhead: needs space for input + output SSTables (~50-100% temporary)
- Best for write-dominated workloads where reads are less frequent
- Drawback: large SSTables may never get compacted with small ones

**LCS:**
- L0 = memtable flushes; L1 = max 10 SSTables of 160MB each; L2 = max 100 of 160MB; etc.
- Each level is 10x the size of the previous level
- A read hits at most one SSTable per level
- Higher write amplification (each datum rewritten ~10x across levels)
- Best for read-heavy workloads with frequent updates

**TWCS:**
- Groups SSTables into time windows (e.g., 1-hour or 1-day buckets)
- Within a window, uses STCS-like compaction
- Once a window closes, SSTables in that window are compacted into one and never touched again
- When TTL expires for an entire window, the SSTable is simply dropped
- **Critical:** Do not use with data that lacks TTL or gets updated across windows

**Selection guidance:**
```
Write-heavy, rarely read          --> STCS
Read-heavy, frequent updates      --> LCS
Time-series with TTL              --> TWCS
Cassandra 5.0+                    --> UCS (replaces all three)
Mixed workload (uncertain)        --> Start with STCS, measure, then switch
```

### Write Path

The write path is designed for maximum throughput:

1. **Coordinator receives write** -- Any node can coordinate
2. **Coordinator determines replicas** -- Uses the partitioner and replication strategy
3. **Write sent to replicas** in parallel
4. **On each replica:**
   a. Write to the **commit log** (sequential append on disk) -- durability guarantee
   b. Write to the **memtable** (in-memory sorted structure)
   c. Acknowledge to coordinator
5. **Coordinator waits** for consistency level acknowledgments, then responds to client
6. **Memtable flush:** When memtable reaches `memtable_cleanup_threshold` or commitlog space limit, it is flushed to an immutable **SSTable** on disk
7. **Compaction** merges SSTables in the background

**Key performance characteristics:**
- Writes are always sequential I/O (commit log append + SSTable flush)
- No read-before-write (unlike RDBMS UPDATE)
- Writes at CL=ONE are acknowledged as soon as a single replica writes to its commit log + memtable
- Hinted handoff: if a replica is down, the coordinator stores a hint and replays it when the node recovers

### Read Path

The read path is more complex due to the LSM-tree storage:

1. **Coordinator receives read** -- Determines replicas using the partitioner
2. **Coordinator sends read request** to the fastest replica (by snitch dynamic latency) and digest requests to enough replicas to satisfy the consistency level
3. **On each replica:**
   a. Check the **memtable** (most recent data)
   b. Check the **row cache** (if enabled -- rarely used in production)
   c. For each SSTable (newest to oldest):
      - Check the **bloom filter** -- probabilistic "definitely not here" or "maybe here"
      - Check the **partition index summary** (in-memory sampling of partition index)
      - Read the **partition index** from disk to find the exact position
      - Check the **compression offset map** to find the compressed chunk
      - Read and decompress the data
   d. **Merge** results from memtable and all SSTables (last-write-wins by timestamp)
4. **Coordinator compares** full data response with digest responses
5. If digests match, return result. If not, trigger a **read repair** in the background.

**Read performance levers:**
- Bloom filter: false-positive rate tunable via `bloom_filter_fp_chance` (default 0.01 = 1%)
- Key cache: caches partition index entries (default ON, 100MB or 5% of heap)
- Compaction: fewer SSTables = fewer lookups per read
- Partition size: smaller partitions = faster reads

### Tombstones and TTL

Cassandra cannot delete data in place (distributed, immutable SSTables). Instead, it writes a **tombstone** -- a marker that says "this data is deleted":

**Types of tombstones:**
- **Cell tombstone** -- Deletes a single column
- **Row tombstone** -- Deletes an entire row
- **Range tombstone** -- Deletes a range of clustering keys within a partition
- **Partition tombstone** -- Deletes an entire partition
- **TTL expiry** -- Automatically generates a tombstone when TTL expires

**gc_grace_seconds (default 864000 = 10 days):**
- Tombstones are kept for this duration to ensure all replicas see the deletion
- After gc_grace_seconds, compaction can purge the tombstone
- If a node is down longer than gc_grace_seconds, it may resurrect deleted data (zombie data)
- **Critical:** Never set gc_grace_seconds to 0 unless you have a single replica or a custom repair strategy

**Tombstone warnings:**
```
# cassandra.yaml
tombstone_warn_threshold: 1000     # warn in logs when reading > 1000 tombstones
tombstone_failure_threshold: 100000 # fail the query when reading > 100000 tombstones
```

**Tombstone storm scenarios:**
- Deleting large ranges of data without considering compaction timing
- Using wide partitions with heavy delete patterns
- TTL expiring on large amounts of data simultaneously
- `SELECT *` on a partition with mostly deleted data -- must scan through all tombstones

**Mitigation strategies:**
1. Design data models to avoid deletes (use TTL with TWCS instead)
2. Keep partitions small (< 100MB, < 100K rows ideal)
3. Run targeted repairs before and after bulk deletes
4. Monitor tombstone counts via `nodetool tablestats` (look at `Average tombstones per slice`)
5. Adjust `gc_grace_seconds` downward (but never below your repair interval)

### Secondary Indexes and Materialized Views

**Secondary Indexes (legacy SASI and 2i):**
- Built as hidden local tables on each node
- Queries must still hit all nodes that could hold matching data (scatter-gather)
- Suitable for low-cardinality columns with a known partition key in the WHERE clause
- **Avoid for:** high-cardinality columns, queries without partition key, high-throughput production queries

**Materialized Views (MV):**
- Server-maintained denormalized tables
- Automatically updated when the base table changes
- Known issues: consistency bugs, repair complications, performance overhead
- **Recommendation:** Avoid in production. Use client-side denormalization with BATCH writes to multiple tables instead.

**Storage Attached Indexes (SAI, Cassandra 5.0+):**
- Replaces SASI and legacy 2i
- Column-level index stored alongside SSTable data
- Efficient for both equality and range queries on non-primary-key columns
- Much better performance and reliability than legacy secondary indexes
- See `5.0/SKILL.md` for details

### Lightweight Transactions (LWT)

Cassandra provides linearizable consistency via a Paxos-based protocol:

```cql
-- INSERT if not exists (compare-and-set)
INSERT INTO users (user_id, email, name)
VALUES (uuid(), 'alice@example.com', 'Alice')
IF NOT EXISTS;

-- UPDATE with condition
UPDATE users SET email = 'new@example.com'
WHERE user_id = some-uuid
IF email = 'old@example.com';

-- DELETE with condition
DELETE FROM users WHERE user_id = some-uuid
IF name = 'Alice';
```

**LWT internals (4-round-trip Paxos):**
1. Prepare -- Propose a ballot number to replicas
2. Promise -- Replicas promise to accept this ballot (or reject if a higher ballot exists)
3. Propose -- Send the actual mutation with the ballot
4. Commit -- Finalize the mutation

**Performance implications:**
- 4x latency of a normal write (4 network round-trips vs 1)
- Contention under high concurrency (Paxos ballot conflicts)
- Use `LOCAL_SERIAL` / `SERIAL` consistency levels for LWT reads
- **Guidance:** Use sparingly. If you need many LWT operations, consider whether Cassandra is the right database for that workload. Typical use cases: unique constraints, account creation, leader election.

### Security

**Authentication:**
```yaml
# cassandra.yaml
authenticator: PasswordAuthenticator   # default: AllowAllAuthenticator
```
```cql
-- Create roles
CREATE ROLE admin WITH PASSWORD = 'strongpassword' AND LOGIN = true AND SUPERUSER = true;
CREATE ROLE app_user WITH PASSWORD = 'apppass' AND LOGIN = true;
```

**Authorization:**
```yaml
# cassandra.yaml
authorizer: CassandraAuthorizer   # default: AllowAllAuthorizer
```
```cql
-- Grant permissions
GRANT SELECT ON KEYSPACE my_ks TO app_user;
GRANT MODIFY ON TABLE my_ks.events TO app_user;
GRANT ALL PERMISSIONS ON KEYSPACE my_ks TO admin;

-- List permissions
LIST ALL PERMISSIONS OF app_user;
```

**Encryption:**
```yaml
# cassandra.yaml -- client-to-node encryption
client_encryption_options:
    enabled: true
    optional: false
    keystore: /etc/cassandra/conf/.keystore
    keystore_password: changeit
    truststore: /etc/cassandra/conf/.truststore
    truststore_password: changeit
    protocol: TLS
    cipher_suites: [TLS_RSA_WITH_AES_256_CBC_SHA]

# Node-to-node encryption (internode)
server_encryption_options:
    internode_encryption: all    # none, dc, rack, all
    keystore: /etc/cassandra/conf/.keystore
    keystore_password: changeit
    truststore: /etc/cassandra/conf/.truststore
    truststore_password: changeit
```

### JVM Tuning

Cassandra runs on the JVM and is sensitive to garbage collection behavior:

**Heap sizing (cassandra-env.sh or jvm.options):**
```bash
# For nodes with <= 32GB RAM, typical heap:
-Xms8G
-Xmx8G
# Never exceed 50% of RAM for heap -- the rest is used for OS page cache and off-heap structures

# For large datasets (>100GB per node):
-Xms16G
-Xmx16G
# 31GB is the practical max due to compressed oops threshold
```

**Garbage collector selection:**
- **G1GC** (recommended for Cassandra 3.11+, 4.x): good throughput, manageable pause times
- **ZGC** (Cassandra 4.1+, Java 11+): ultra-low pause times, experimental in 4.x
- **Shenandoah** (alternative low-pause): supported on some JDK distributions

**G1GC tuning (jvm11-server.options):**
```
-XX:+UseG1GC
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:MaxGCPauseMillis=300
-XX:InitiatingHeapOccupancyPercent=70
-XX:ParallelGCThreads=<num_cpu_cores>
-XX:ConcGCThreads=<num_cpu_cores / 4>
```

**Off-heap memory:**
Cassandra uses significant off-heap memory for:
- Bloom filters
- Partition index summary
- Compression offset maps
- Key cache
- Chunk cache (4.0+)
- Networking buffers

**Rule of thumb:** Total process memory = heap + off-heap + OS page cache. Plan for heap to be 25-50% of total RAM.

### Multi-Datacenter Replication

```cql
-- Create keyspace with multi-DC replication
CREATE KEYSPACE global_ks WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'us-east': 3,
    'eu-west': 3
};
```

**Configuration requirements:**
- Each node must have `GossipingPropertyFileSnitch` or a cloud-specific snitch
- `cassandra-rackdc.properties` on each node:
  ```
  dc=us-east
  rack=rack1
  ```
- Use `LOCAL_QUORUM` consistency level for reads and writes (isolates latency to local DC)
- Use `EACH_QUORUM` for writes when cross-DC consistency is required (higher latency)

**Multi-DC topology considerations:**
- RF=3 per datacenter is the standard (total 6 replicas for 2 DCs)
- Remote DC replicas are updated asynchronously (from the client's perspective when using LOCAL_QUORUM)
- One DC can serve reads independently if the other DC goes down entirely
- Schema changes propagate via gossip; use `nodetool describecluster` to check for schema disagreements

## Common Pitfalls

1. **Hot partitions** -- A single partition key receiving disproportionate traffic. Caused by low-cardinality partition keys or skewed data distribution. Monitor with `nodetool tablehistograms` and check partition size distribution.

2. **Unbounded partition growth** -- Partitions growing without limit (e.g., all events for a user in one partition). Always bucket partitions with a time or sequence component.

3. **Using BATCH for performance** -- Batches in Cassandra are NOT for performance. They are for atomicity on the same partition. Cross-partition batches add coordinator overhead and increase latency.

4. **ALLOW FILTERING in production** -- This tells Cassandra to read all partitions and filter server-side. Suitable only for small tables or development. In production, design a table that serves the query directly.

5. **Neglecting repair** -- Without regular repair, replicas diverge and read repairs alone cannot keep up. Run full repair within every gc_grace_seconds window (default 10 days). Use incremental repair in 4.0+ for efficiency.

6. **Setting gc_grace_seconds too low** -- If a node is down longer than gc_grace_seconds, purged tombstones may cause deleted data to reappear (zombie data). Always keep gc_grace_seconds > your longest expected outage + repair cycle.

7. **Oversized partitions** -- Partitions > 100MB cause compaction pressure, GC pauses, and read latency spikes. Target < 100MB and < 100K cells per partition.

8. **Running multiple repairs simultaneously** -- Concurrent repairs compete for CPU, disk I/O, and network. Run repairs sequentially, one node or token range at a time.

## Version Routing

| Version | Status | Key Feature | Route To |
|---|---|---|---|
| **Cassandra 5.0** | Current (Sep 2024) | SAI, UCS, trie indexes, vector search, Java 17 | `5.0/SKILL.md` |
| **Cassandra 4.x** | Supported (4.0: Jul 2021, 4.1: Dec 2022) | Virtual tables, audit logging, incremental repair v2, Java 11 | `4.x/SKILL.md` |
| **Cassandra 3.11** | EOL (legacy) | Last 3.x release; widely deployed legacy systems | Not covered (upgrade recommended) |

## Reference Files

Load these when you need deep knowledge for a specific area:

- `references/architecture.md` -- Write path internals, read path internals, SSTable format, bloom filters, gossip protocol, failure detection, hinted handoff, read repair, anti-entropy repair, Paxos, streaming protocol, snitch types. Read for "how does Cassandra work internally" questions.
- `references/diagnostics.md` -- 100+ nodetool commands, cqlsh diagnostics, system table queries, CQL tracing, JMX metrics, log analysis patterns, troubleshooting playbooks. Read when troubleshooting performance, cluster health, or operational issues.
- `references/best-practices.md` -- Data modeling methodology, partition sizing, cluster sizing, hardware selection, cassandra.yaml tuning, JVM settings, compaction strategy selection, repair scheduling, backup strategies, monitoring setup, security hardening, multi-DC deployment. Read for configuration and operational guidance.
