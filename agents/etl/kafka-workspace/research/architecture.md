# Apache Kafka Architecture

> Research date: 2026-04-09
> Covers: Kafka 3.9 through 4.2 (current)

---

## 1. Core Architecture: Brokers, Topics, Partitions

### Brokers

A **broker** is a Kafka server process that stores data on disk and serves client requests (produce, fetch, metadata). A Kafka **cluster** consists of multiple brokers working together to distribute load and provide fault tolerance. Each broker is identified by a unique `broker.id`.

Key broker responsibilities:
- Storing log segments for assigned partitions
- Serving produce and fetch requests from clients
- Participating in replica synchronization
- Reporting metadata to the controller (KRaft quorum or, historically, ZooKeeper)

### Topics

A **topic** is a named, logical stream of records -- the fundamental unit of organization in Kafka. Topics are append-only, immutable logs. Producers write to topics; consumers read from topics.

### Partitions

Each topic is divided into one or more **partitions**. Partitions are the unit of parallelism and ordering in Kafka:
- Records within a single partition are strictly ordered by offset
- Each partition is an independent, append-only commit log stored on disk
- Partitions are distributed across brokers for load balancing
- A **partition key** determines which partition a record is routed to (via hashing)

### Segments

Each partition is physically stored as a sequence of **log segments** on disk:
- Active segment: currently being written to
- Closed segments: immutable, eligible for retention/compaction
- Each segment is a pair of files: `.log` (data) and `.index` (offset-to-position mapping), plus `.timeindex` (timestamp index)
- Segment size controlled by `log.segment.bytes` (default 1 GB) or `log.roll.ms`/`log.roll.hours`

---

## 2. Replication and ISR

### Replicas

Each partition has a configurable number of **replicas** (set by `replication.factor`, typically 3 in production). One replica is the **leader**; the rest are **followers**.

- **Leader**: Handles ALL produce and fetch requests for the partition
- **Followers**: Replicate data from the leader by issuing fetch requests
- Leadership is distributed across brokers to balance load

### In-Sync Replicas (ISR)

The **ISR** (In-Sync Replica set) is the subset of replicas that are caught up with the leader:
- A follower is in the ISR if it has replicated all messages within `replica.lag.time.max.ms` (default 30,000 ms)
- The leader tracks which followers are in the ISR
- `acks=all` means the leader waits for ALL ISR members to acknowledge before confirming a write
- If a follower falls behind, it is removed from the ISR (triggers `IsrShrinksPerSec` metric)
- When it catches up, it is added back (triggers `IsrExpandsPerSec` metric)

### Leader Election

- When a leader fails, a new leader is elected from the ISR
- `unclean.leader.election.enable=false` (default) prevents out-of-sync replicas from becoming leader (prevents data loss, but may cause unavailability)
- **Kafka 4.0+**: KIP-966 introduces **Eligible Leader Replicas (ELR)** -- a subset of ISR replicas guaranteed to have complete data up to the high-watermark, enabling clean elections even after unclean broker shutdowns

### High Watermark

The **high watermark** is the offset of the last record that has been replicated to ALL ISR members. Consumers with `isolation.level=read_committed` only see records up to the high watermark (or the last stable offset for transactional data).

---

## 3. Producer Internals

### Record Accumulator and Batching

The producer does not send each record individually. Instead:
1. `send()` adds the record to an internal **RecordAccumulator** buffer and returns immediately (async)
2. Records are grouped into **batches** by topic-partition
3. A background **Sender** thread transmits full batches to the appropriate broker
4. Batching is controlled by:
   - `batch.size` (default 16,384 bytes / 16 KB): maximum batch size in bytes
   - `linger.ms` (default 5 ms in Kafka 4.x): how long to wait for more records before sending a partial batch
   - `buffer.memory` (default 33,554,432 bytes / 32 MB): total memory available for buffering

### Compression

Compression is applied at the **batch level** (not per-record), so larger batches yield better compression:
- `compression.type`: `none` (default), `gzip`, `snappy`, `lz4`, `zstd`
- `zstd` generally offers the best compression ratio; `lz4` offers the best speed
- Broker can re-compress if `compression.type` at broker level differs (avoid this)

### Acknowledgements (acks)

Controls durability guarantees:
- `acks=0`: Fire and forget. No acknowledgement. Highest throughput, risk of data loss.
- `acks=1`: Leader acknowledges after writing to its local log. Risk of data loss if leader fails before replication.
- `acks=all` (or `acks=-1`): Leader waits for ALL ISR replicas to acknowledge. Strongest durability. Combined with `min.insync.replicas=2`, ensures at least 2 replicas have the data.

### Idempotent Producer

Guarantees exactly-once delivery to a single partition (no duplicates from retries):
- Enabled by default in Kafka 3.0+ (`enable.idempotence=true`)
- The broker assigns a **Producer ID (PID)** and tracks a **sequence number** per partition
- Duplicate records (same PID + sequence) are silently rejected
- Requires: `acks=all`, `retries > 0`, `max.in.flight.requests.per.connection <= 5`

### Transactional Producer

Extends idempotent producer for atomic writes across multiple partitions:
- Configured via `transactional.id` (a unique, stable identifier for the producer instance)
- API: `initTransactions()`, `beginTransaction()`, `send()`, `sendOffsetsToTransaction()`, `commitTransaction()`, `abortTransaction()`
- Enables exactly-once when combined with `read_committed` consumers
- Uses a **Transaction Coordinator** (a broker that manages the transaction log `__transaction_state`)
- Transaction timeout controlled by `transaction.timeout.ms` (default 60,000 ms)

---

## 4. Consumer Internals

### Consumer Groups

A **consumer group** is a set of consumers that cooperatively consume from one or more topics:
- Each partition is assigned to exactly ONE consumer within a group
- Multiple groups can independently consume the same topic
- The **Group Coordinator** (a broker) manages group membership and partition assignment
- Coordinator is determined by hashing `group.id` to a partition of `__consumer_offsets`

### Offset Management

- Each consumer tracks its position (offset) in each assigned partition
- Offsets are committed to the internal `__consumer_offsets` topic (50 partitions by default)
- `enable.auto.commit=true` (default): offsets committed periodically (`auto.commit.interval.ms`, default 5000 ms)
- Manual commit: `commitSync()` or `commitAsync()` for precise control
- On startup, consumer reads from `auto.offset.reset`: `latest` (default), `earliest`, or `none`

### Rebalancing Protocols

**Eager Rebalance (legacy):**
- Stop-the-world: ALL consumers revoke ALL partitions, then re-join and get new assignments
- Causes a processing gap across the entire group
- Strategies: RangeAssignor, RoundRobinAssignor

**Cooperative (Incremental) Rebalance (Kafka 2.4+):**
- Two-phase process: only the specific partitions being moved are revoked
- Unaffected consumers continue processing without interruption
- Strategy: CooperativeStickyAssignor (default alongside RangeAssignor in Kafka 3.x)

**KIP-848 New Consumer Group Protocol (Kafka 4.0 GA):**
- Server-side partition assignment (broker manages assignments, not a consumer leader)
- Continuous heartbeat mechanism replaces JoinGroup/SyncGroup phases
- Eliminates stop-the-world rebalances entirely
- Opt-in via `group.protocol=consumer` (client-side)
- Enabled by default on the server in Kafka 4.0

**Static Group Membership:**
- Consumer sets `group.instance.id` to a stable identifier
- Consumer retains its partition assignment across restarts (within `session.timeout.ms`)
- Prevents unnecessary rebalances in containerized/Kubernetes environments

---

## 5. KRaft Consensus (Replacement for ZooKeeper)

### Background

KRaft (Kafka Raft) was introduced in KIP-500 to remove Kafka dependency on ZooKeeper for metadata management. Timeline:
- **Kafka 2.8** (2021): KRaft early access (development only)
- **Kafka 3.3** (2022): KRaft marked production-ready for new clusters
- **Kafka 3.5**: KRaft GA
- **Kafka 3.9** (Nov 2024): Last version supporting ZooKeeper; bridge release for migration
- **Kafka 4.0** (March 2025): ZooKeeper REMOVED entirely; KRaft-only

### Architecture

- A set of **controller nodes** form a **quorum** using an event-based variant of the Raft consensus protocol
- One controller is the **active controller** (leader); others are hot standbys
- Metadata is stored in an internal topic called `__cluster_metadata` (formerly `@metadata`)
- All brokers subscribe to this metadata topic and maintain a local cache

### Benefits over ZooKeeper
- Simplified architecture: one system instead of two
- Faster controller failover (seconds vs. potentially minutes)
- Supports millions of partitions per cluster (ZooKeeper was a bottleneck at ~200K)
- Reduced operational complexity: no ZooKeeper to deploy, monitor, secure, or scale
- Single security model for the entire cluster

### KRaft Dynamic Quorums (Kafka 3.9+, KIP-853)
- Controller membership is now dynamic -- add/remove controller nodes without downtime
- Managed via `kafka-metadata-quorum.sh` tool or AdminClient API

---

## 6. Kafka Connect

### Architecture

Kafka Connect is a framework for streaming data between Kafka and external systems:
- **Connectors**: High-level abstractions that coordinate data streaming by managing tasks
- **Tasks**: The implementation of how data is actually copied (each connector spawns one or more tasks)
- **Workers**: JVM processes that execute connectors and tasks
- **Converters**: Translate between Connect internal data format and serialization formats (Avro, JSON, Protobuf)
- **Transforms (SMTs)**: Simple, single-message transformations applied in a pipeline chain

### Source vs Sink Connectors
- **Source connectors**: Ingest data FROM external systems INTO Kafka (e.g., JDBC Source, Debezium CDC)
- **Sink connectors**: Deliver data FROM Kafka TO external systems (e.g., Elasticsearch Sink, S3 Sink, HDFS Sink)

### Converters
Converters serialize/deserialize data between Connect internal representation and wire format:
- `JsonConverter`: JSON (with or without schema)
- `AvroConverter`: Avro (requires Schema Registry)
- `ProtobufConverter`: Protobuf (requires Schema Registry)
- `StringConverter`, `ByteArrayConverter`: raw formats
- Converters are **decoupled** from connectors -- any connector can use any converter

### Single Message Transforms (SMTs)
Built-in transforms include:
- `InsertField`, `ReplaceField`, `MaskField`: field manipulation
- `ValueToKey`, `ExtractField`: key/value extraction
- `TimestampRouter`, `RegexRouter`: topic routing
- `Cast`, `Flatten`, `HeaderFrom`: type and structure changes
- Chained as an ordered list; each transform receives the output of the previous one

### Dead Letter Queue (DLQ)
- Applicable to **sink connectors only**
- Failed records are routed to a DLQ topic instead of being silently dropped
- Configuration: `errors.tolerance=all`, `errors.deadletterqueue.topic.name=<topic>`
- DLQ records include error context in headers (exception class, message, stack trace)
- Enables inspection and reprocessing of failed records

### Deployment Modes
- **Standalone mode**: Single worker process; configuration via properties files; no fault tolerance; suitable for development/testing
- **Distributed mode**: Multiple workers; configuration via REST API; automatic task distribution and failover; recommended for production

---

## 7. Kafka Streams

### Overview

Kafka Streams is a client library for building stateful stream processing applications on top of Kafka. It has no external dependencies beyond Kafka itself.

### Topology

A Kafka Streams application defines a **topology** -- a directed acyclic graph (DAG) of:
- **Source processors**: Read from Kafka topics
- **Stream processors**: Apply transformations (map, filter, join, aggregate)
- **Sink processors**: Write results to Kafka topics

Two APIs:
- **DSL (Domain Specific Language)**: High-level, declarative (KStream, KTable, GlobalKTable)
- **Processor API**: Low-level, imperative (custom processors with direct state store access)

### State Stores

- Kafka Streams uses **local state stores** (RocksDB by default) for stateful operations
- State is backed up to **changelog topics** in Kafka for fault tolerance
- State stores enable fast, in-memory-like access without external databases
- Types: persistent (RocksDB), in-memory, custom

### Exactly-Once Processing

- `processing.guarantee=exactly_once_v2` (Kafka 2.5+, recommended)
- Combines transactional producer, idempotent producer, and read_committed consumers
- Guarantees each input record is processed exactly once, and all outputs and state updates are atomic

### Windowing

Controls how records with the same key are grouped for stateful operations:
- **Tumbling windows**: Fixed-size, non-overlapping, time-based
- **Hopping windows**: Fixed-size, overlapping (hop interval < window size)
- **Sliding windows**: Fixed-size, overlapping, triggered by record timestamps
- **Session windows**: Dynamic size, defined by inactivity gap
- **Grace period**: How long to wait for out-of-order/late records after window closes

### Joins

- **KStream-KStream join**: Windowed join between two event streams
- **KTable-KTable join**: Changelog-based join (always latest value per key)
- **KStream-KTable join**: Enrich stream events with table lookups
- **KStream-GlobalKTable join**: Broadcast join (entire table on every instance, non-partitioned key join)

---

## 8. Schema Registry

### Overview

Schema Registry (Confluent) provides a centralized repository for schemas, enabling data governance and schema evolution for Kafka topics.

### Supported Formats
- **Apache Avro**: Binary, compact, schema embedded in registry (most mature support)
- **Protocol Buffers (Protobuf)**: Google serialization format; strong typing
- **JSON Schema**: Human-readable; less compact but more accessible

### How It Works
1. Producer registers schema with Schema Registry, gets a schema ID
2. Producer serializes data using schema, prepends schema ID (magic byte + 4-byte ID)
3. Consumer fetches schema by ID from registry, deserializes data
4. Schema Registry caches schemas in `_schemas` topic (Kafka-backed)

### Compatibility Modes

| Mode | Description | Safe Changes |
|------|-------------|-------------|
| `BACKWARD` (default) | New schema can read data written with previous schema | Delete fields, add optional fields with defaults |
| `BACKWARD_TRANSITIVE` | New schema can read data from ALL previous schemas | Same as BACKWARD, across all versions |
| `FORWARD` | Previous schema can read data written with new schema | Add fields, delete optional fields with defaults |
| `FORWARD_TRANSITIVE` | All previous schemas can read data from new schema | Same as FORWARD, across all versions |
| `FULL` | Both backward and forward compatible with previous | Add/delete optional fields with defaults |
| `FULL_TRANSITIVE` | Both backward and forward compatible with ALL previous | Same as FULL, across all versions |
| `NONE` | No compatibility checking | Any change allowed (dangerous) |

### Best Practices
- Use `BACKWARD` (default) for most Kafka use cases (allows consumer rewind)
- Protobuf: Use `BACKWARD_TRANSITIVE` (adding new message types is not forward compatible)
- Always provide default values for new fields in Avro
- Kafka Streams only supports `BACKWARD` compatibility

---

## 9. Storage

### Log Segments

Kafka stores data as log segments on disk:
- Each partition is a directory containing segment files
- Active segment is open for writes; closed segments are immutable
- Files per segment: `.log`, `.index`, `.timeindex`, `.snapshot` (optional), `.txnindex` (for transactions)
- Segment rotation triggered by `log.segment.bytes` (1 GB) or `log.roll.ms`

### Retention Policies

Three cleanup policies (`cleanup.policy`):
- **`delete`** (default): Old segments removed when they exceed `retention.ms` (default 7 days) or `retention.bytes` (default unlimited)
- **`compact`**: Log compaction retains only the LATEST value for each key; older values are removed by a background **Log Cleaner** thread
- **`compact,delete`**: Both policies apply -- compacted segments are also subject to time/size retention

### Log Compaction Details

- The log is divided into a **clean** portion (already compacted) and a **dirty** portion (not yet compacted)
- Compaction preserves the most recent value for each key and removes older duplicates
- **Tombstones** (records with null value) signal key deletion; retained for `delete.retention.ms` (default 24 hours) before removal
- Key configs: `min.cleanable.dirty.ratio` (default 0.5), `min.compaction.lag.ms`, `max.compaction.lag.ms`

### Tiered Storage (Kafka 3.9+ Production-Ready, KIP-405)

Extends storage beyond local broker disks:
- **Local tier**: Recent data on broker disks (low-latency tail reads)
- **Remote tier**: Older data offloaded to object storage (S3, GCS, Azure Blob, HDFS)
- Transparent to consumers -- fetch requests seamlessly retrieve from either tier
- Reduces broker storage costs and enables longer retention
- Configured per topic: `remote.storage.enable=true`, `local.retention.ms`, `local.retention.bytes`

---

## 10. Exactly-Once Semantics (EOS)

### The Three Components

Exactly-once in Kafka requires three cooperating mechanisms:

1. **Idempotent Producer**: Prevents duplicate records from retries (PID + sequence number deduplication)
2. **Transactional Producer**: Atomic writes across multiple partitions; atomic commit of consumer offsets + produced records
3. **Read Committed Consumers**: `isolation.level=read_committed` ensures consumers only see committed transactional records

### How It Works End-to-End

1. Consumer reads records with `isolation.level=read_committed`
2. Application processes records
3. Transactional producer writes output records AND commits input offsets in a single atomic transaction
4. If any step fails, the entire transaction is aborted; consumer re-reads from last committed offset

### Key Configurations

| Config | Value | Purpose |
|--------|-------|---------|
| `enable.idempotence` | `true` (default 3.0+) | Enable PID-based dedup |
| `transactional.id` | unique string | Enable transactions |
| `acks` | `all` | Required for idempotence |
| `isolation.level` | `read_committed` | Consumer sees only committed data |
| `processing.guarantee` | `exactly_once_v2` | Kafka Streams EOS |
| `enable.auto.commit` | `false` | Required for transactional offset commits |

### Limitations
- Exactly-once applies within Kafka -- external side effects (database writes, API calls) require additional patterns (outbox, saga)
- Transactions add latency (~10-50ms overhead per transaction)
- `transactional.id` must be stable and unique per producer instance

---

## Sources

- [Conduktor - Kafka Topics, Partitions, Brokers](https://www.conduktor.io/glossary/kafka-topics-partitions-brokers-core-architecture)
- [Instaclustr - Kafka Architecture Complete Guide 2026](https://www.instaclustr.com/education/apache-kafka/apache-kafka-architecture-a-complete-guide-2026/)
- [Confluent - Kafka Replication](https://docs.confluent.io/kafka/design/replication.html)
- [Confluent - KRaft](https://developer.confluent.io/learn/kraft/)
- [Confluent - KIP-848 Consumer Rebalance Protocol](https://www.confluent.io/blog/kip-848-consumer-rebalance-protocol/)
- [Confluent - Kafka Connect](https://docs.confluent.io/platform/current/connect/index.html)
- [Confluent - Dead Letter Queues](https://www.confluent.io/blog/kafka-connect-deep-dive-error-handling-dead-letter-queues/)
- [Confluent - Schema Evolution](https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html)
- [Confluent - Message Delivery Guarantees](https://docs.confluent.io/kafka/design/delivery-semantics.html)
- [Confluent - Transactions](https://developer.confluent.io/courses/architecture/transactions/)
- [Apache Kafka - Core Concepts (Streams)](https://kafka.apache.org/42/streams/core-concepts/)
- [Strimzi - Kafka Transactions](https://strimzi.io/blog/2023/05/03/kafka-transactions/)
- [Strimzi - Kafka Segment Retention](https://strimzi.io/blog/2021/12/17/kafka-segment-retention/)
- [Cloudurable - Kafka Architecture 2025](https://cloudurable.com/blog/kafka-architecture-2025)
