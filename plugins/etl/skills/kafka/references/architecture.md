# Apache Kafka Architecture Reference

## Broker Internals

### Broker Responsibilities

A broker is a Kafka server process that stores data on disk and serves client requests. Each broker is identified by a unique `broker.id`. Core responsibilities:

- Storing log segments for assigned partitions
- Serving produce and fetch requests from clients
- Participating in replica synchronization (leader or follower role per partition)
- Reporting metadata to the controller (KRaft quorum)
- Managing consumer group coordination (for groups hashed to this broker)

### Request Processing

Brokers use a multi-threaded architecture:

1. **Network threads** (`num.network.threads`, default 3): Accept connections, read requests from the socket, and place them on the request queue
2. **Request handler threads** (`num.io.threads`, default 8): Process requests from the queue (produce, fetch, metadata, offsets)
3. **Purgatory**: Holds delayed requests (e.g., `acks=all` produce waiting for ISR, fetch waiting for `fetch.min.bytes`)

Key metrics for saturation:
- `RequestHandlerAvgIdlePercent` < 30% indicates I/O thread saturation
- `NetworkProcessorAvgIdlePercent` < 30% indicates network thread saturation

### Log Storage

Each partition is a directory on disk containing ordered log segments:

```
/kafka-data/orders-0/
  00000000000000000000.log        # Segment data (records)
  00000000000000000000.index      # Offset-to-position index
  00000000000000000000.timeindex  # Timestamp-to-offset index
  00000000000052345678.log        # Next segment (named by base offset)
  00000000000052345678.index
  00000000000052345678.timeindex
  leader-epoch-checkpoint          # Leader epoch history
  partition.metadata               # Partition metadata
```

- **Active segment**: Currently being written to. One per partition.
- **Closed segments**: Immutable. Eligible for retention or compaction.
- Segment rotation triggered by `log.segment.bytes` (default 1 GB) or `log.roll.ms`/`log.roll.hours`
- Transaction index files (`.txnindex`) present when transactions are used

## Replication

### Leader-Follower Model

Each partition has `replication.factor` replicas distributed across brokers. One replica is the **leader**; the rest are **followers**.

- **Leader**: Handles ALL produce and fetch requests for the partition
- **Followers**: Replicate data by issuing fetch requests to the leader (pull-based)
- Leadership is distributed across brokers to balance load
- `auto.leader.rebalance.enable=true` (default) periodically restores preferred leader assignment

### In-Sync Replicas (ISR)

The ISR is the subset of replicas caught up with the leader:

- A follower is in the ISR if it has replicated all messages within `replica.lag.time.max.ms` (default 30,000 ms)
- The leader tracks which followers are in the ISR and reports changes to the controller
- `acks=all` means the leader waits for ALL ISR members to acknowledge before confirming a write
- ISR shrinks trigger `IsrShrinksPerSec` metric; expansions trigger `IsrExpandsPerSec`

### Eligible Leader Replicas (ELR) -- Kafka 4.0+

KIP-966 introduces ELR -- a subset of ISR replicas guaranteed to have complete data up to the high watermark:

- Prevents data loss during unclean broker shutdowns where ISR may include lagging replicas
- Preview in 4.0 (opt-in via `eligible.leader.replicas.version=1`)
- Enabled by default in 4.1+
- Only ELR members are eligible for clean leader election

### High Watermark

The high watermark is the offset of the last record replicated to ALL ISR members:

- Consumers only see records up to the high watermark (or last stable offset for transactional data)
- The leader advances the high watermark as followers catch up
- `isolation.level=read_committed` consumers see records up to the last stable offset (committed transactions only)

### Leader Election

- When a leader fails, a new leader is elected from the ISR (or ELR if enabled)
- `unclean.leader.election.enable=false` (default) prevents out-of-sync replicas from becoming leader
- Setting to `true` trades data loss risk for availability (use only when availability > consistency)

## KRaft Consensus

### Architecture

KRaft (Kafka Raft) replaced ZooKeeper for metadata management in Kafka 4.0:

```
┌─────────────────────────────────┐
│       KRaft Controller Quorum    │
│  ┌──────────┐ ┌────────┐ ┌────────┐  │
│  │Controller│ │Ctrl    │ │Ctrl    │  │
│  │(Active)  │ │Standby │ │Standby │  │
│  └────┬─────┘ └───┬────┘ └───┬────┘  │
│       └─────┬─────┘──────────┘       │
│             │ __cluster_metadata      │
└─────────────┼────────────────────────┘
              │ Metadata pushed to brokers
     ┌────────┼────────┐
     │        │        │
  Broker 1  Broker 2  Broker 3
  (cache)   (cache)   (cache)
```

- A set of **controller nodes** form a quorum using an event-based Raft protocol
- One controller is the **active controller** (leader); others are hot standbys
- Metadata stored in `__cluster_metadata` internal topic
- All brokers subscribe to the metadata topic and maintain a local cache

### Node Roles

Nodes can have one or both roles:

- `process.roles=controller` -- Controller-only node (recommended for large clusters)
- `process.roles=broker` -- Broker-only node (recommended for large clusters)
- `process.roles=controller,broker` -- Combined role (acceptable for small clusters, 3-5 nodes)

### Benefits over ZooKeeper

- **Simplified operations**: One system instead of two
- **Faster failover**: Controller election in seconds (vs potentially minutes with ZK)
- **Scalability**: Supports millions of partitions per cluster (ZK bottlenecked at ~200K)
- **Single security model**: One authentication/authorization configuration
- **Reduced operational burden**: No ZooKeeper deployment, monitoring, or scaling

### Dynamic Quorums (KIP-853, Kafka 3.9+)

Controller membership is dynamic -- add/remove controller nodes without cluster downtime:

```bash
# Add a new controller to the quorum
kafka-metadata-quorum.sh --bootstrap-controller <controller>:9093 \
  add-controller --controller-id 4 --controller-directory-id <uuid>

# Remove a controller from the quorum
kafka-metadata-quorum.sh --bootstrap-controller <controller>:9093 \
  remove-controller --controller-id 4 --controller-directory-id <uuid>
```

### ZooKeeper to KRaft Migration

Migration is a four-phase process performed on Kafka 3.9 (mandatory before upgrading to 4.0):

**Phase 1 -- Preparation**: Upgrade cluster to 3.9, document config, back up ZK and broker data, plan controller placement (3 or 5 nodes).

**Phase 2 -- Provision Controllers**: Deploy KRaft controller nodes, configure `controller.quorum.voters`, start controllers, generate cluster ID with `kafka-storage.sh random-uuid`.

**Phase 3 -- Broker Migration (Rolling)**: Configure brokers for dual-write mode (both ZK and KRaft). Rolling restart. Metadata written to both during this phase. Verify consistency.

**Phase 4 -- Finalize**: Verify all brokers registered with KRaft controller. Run `kafka-metadata.sh` to validate. Finalize migration (irreversible). Decommission ZooKeeper.

**Critical**: No downgrade path after finalization. Rollback is only possible before the finalize step. Must migrate on 3.9 BEFORE upgrading to 4.0.

## Storage

### Retention Policies

Three cleanup policies (`cleanup.policy`):

- **`delete`** (default): Old segments removed when they exceed `retention.ms` (default 7 days) or `retention.bytes` (default unlimited)
- **`compact`**: Log compaction retains only the latest value for each key
- **`compact,delete`**: Both policies apply -- compacted segments also subject to time/size retention

### Log Compaction

Compaction preserves the most recent value for each key and removes older duplicates:

- Log divided into **clean** (already compacted) and **dirty** (not yet compacted) portions
- **Tombstones** (records with null value) signal key deletion; retained for `delete.retention.ms` (default 24h)
- Background Log Cleaner thread performs compaction when `min.cleanable.dirty.ratio` (default 0.5) is exceeded
- Key configs: `min.compaction.lag.ms`, `max.compaction.lag.ms`, `log.cleaner.threads` (default 1)

### Tiered Storage (KIP-405, Production-Ready in Kafka 3.9+)

Extends storage beyond local broker disks:

- **Local tier**: Recent data on broker disks (low-latency tail reads)
- **Remote tier**: Older data offloaded to object storage (S3, GCS, Azure Blob, HDFS)
- Transparent to consumers -- fetch requests seamlessly retrieve from either tier
- Reduces broker storage costs and enables much longer retention periods

Configuration per topic:
```properties
remote.storage.enable=true
local.retention.ms=86400000        # Keep 1 day locally
local.retention.bytes=-1           # No local byte limit
retention.ms=2592000000            # Total retention: 30 days (remote)
```

## Schema Registry

### How It Works

1. Producer registers schema with Schema Registry, receives a schema ID
2. Producer serializes data using schema, prepends magic byte + 4-byte schema ID
3. Consumer fetches schema by ID from registry, deserializes data
4. Schemas cached in `_schemas` topic (Kafka-backed)

### Compatibility Modes

| Mode | Description | Safe Changes |
|------|-------------|-------------|
| `BACKWARD` (default) | New schema reads data from previous schema | Delete fields, add optional fields with defaults |
| `BACKWARD_TRANSITIVE` | New schema reads data from ALL previous schemas | Same, across all versions |
| `FORWARD` | Previous schema reads data from new schema | Add fields, delete optional fields with defaults |
| `FORWARD_TRANSITIVE` | All previous schemas read data from new schema | Same, across all versions |
| `FULL` | Both backward and forward with previous | Add/delete optional fields with defaults |
| `FULL_TRANSITIVE` | Both backward and forward with ALL previous | Same, across all versions |
| `NONE` | No checking | Any change (dangerous -- never in production) |

### Format Guidance

- **Avro**: Most mature Kafka support. Binary, compact. Use `["null", "string"]` union types for optional fields. Always provide defaults.
- **Protobuf**: Strong typing. Use `BACKWARD_TRANSITIVE` (adding message types is not forward compatible). Use `optional` keyword.
- **JSON Schema**: Human-readable, less compact. Set `additionalProperties: true` for forward compatibility. Use `FULL_TRANSITIVE` for safety.

## Kafka Connect Deep Dive

### Architecture

```
┌──────────────────────────────────────────────┐
│             Connect Cluster                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Worker 1 │  │ Worker 2 │  │ Worker 3 │   │
│  │ Task A-0 │  │ Task A-1 │  │ Task B-0 │   │
│  │ Task B-1 │  │ Task A-2 │  │          │   │
│  └──────────┘  └──────────┘  └──────────┘   │
│                                              │
│  Internal topics:                             │
│   connect-offsets (source connector offsets)  │
│   connect-configs (connector configurations) │
│   connect-status  (connector/task status)    │
└──────────────────────────────────────────────┘
```

- **Connectors** coordinate data streaming by managing tasks
- **Tasks** implement actual data copying (each connector spawns one or more)
- **Workers** are JVM processes that execute connectors and tasks
- **Converters** translate between Connect's internal format and serialization (Avro, JSON, Protobuf)
- **SMTs** apply single-message transformations in a pipeline chain

### Dead Letter Queue (Sink Connectors Only)

```properties
errors.tolerance=all
errors.deadletterqueue.topic.name=my-connector-dlq
errors.deadletterqueue.topic.replication.factor=3
errors.deadletterqueue.context.headers.enable=true
```

Failed records routed to DLQ topic with error context in headers (exception class, message, stack trace). Enables inspection and reprocessing.

### Exactly-Once Sink Delivery (Kafka 3.3+)

```properties
# Connect worker configuration
exactly.once.support=required
```

Connector must support it (e.g., JDBC Sink with idempotent upserts). Combines transactional offset management with connector-level guarantees.

## Kafka Streams Deep Dive

### Topology

A Kafka Streams application defines a topology -- a DAG of processors:

- **Source processors**: Read from Kafka topics
- **Stream processors**: Transform (map, filter, join, aggregate)
- **Sink processors**: Write to Kafka topics

### State Stores

- Local state stores (RocksDB by default) for stateful operations (aggregations, joins)
- Backed by changelog topics in Kafka for fault tolerance
- Types: persistent (RocksDB), in-memory, custom
- Standby replicas (`num.standby.replicas`) reduce failover time

### Windowing

| Type | Behavior | Use Case |
|------|----------|----------|
| Tumbling | Fixed-size, non-overlapping | Hourly aggregations |
| Hopping | Fixed-size, overlapping (hop < window) | Sliding averages |
| Sliding | Fixed-size, triggered by record timestamps | Diff-based joins |
| Session | Dynamic size, defined by inactivity gap | User session analytics |

Grace period (`grace()`) controls how long to accept late/out-of-order records after window closes.

### Joins

| Join Type | Description | Requirement |
|-----------|-------------|-------------|
| KStream-KStream | Windowed join between two event streams | Both streams must be co-partitioned |
| KTable-KTable | Changelog join (latest value per key) | Both tables must be co-partitioned |
| KStream-KTable | Enrich stream events with table lookups | Must be co-partitioned |
| KStream-GlobalKTable | Broadcast join (full table on every instance) | No co-partitioning needed |

## Exactly-Once Semantics Internals

### Three Components

1. **Idempotent Producer**: Broker assigns Producer ID (PID), tracks sequence numbers per partition. Duplicates from retries silently rejected.
2. **Transactional Producer**: Uses `transactional.id` for atomic writes across partitions. Transaction Coordinator (broker) manages `__transaction_state` topic.
3. **Read Committed Consumer**: `isolation.level=read_committed` ensures only committed transactional records visible.

### End-to-End Flow

```
Consumer (read_committed) ──► Process ──► Transactional Producer
     │                                         │
     ├── sendOffsetsToTransaction() ──────────►│
     │                                         │
     └── commitTransaction() ─────────────────►│
```

1. Consumer reads with `isolation.level=read_committed`
2. Application processes records
3. Transactional producer writes outputs AND commits input offsets in a single atomic transaction
4. On failure, entire transaction aborts; consumer re-reads from last committed offset

### Key Configurations

| Config | Value | Purpose |
|--------|-------|---------|
| `enable.idempotence` | `true` (default 3.0+) | PID-based dedup |
| `transactional.id` | unique stable string | Enable transactions |
| `acks` | `all` | Required for idempotence |
| `isolation.level` | `read_committed` | See only committed data |
| `processing.guarantee` | `exactly_once_v2` | Kafka Streams EOS |
| `enable.auto.commit` | `false` | Required for transactional consumers |

### Limitations

- Exactly-once applies within Kafka only. External side effects (DB writes, API calls) require outbox or idempotent write patterns.
- Transactions add ~10-50ms overhead per transaction.
- `transactional.id` must be stable and unique per producer instance.
