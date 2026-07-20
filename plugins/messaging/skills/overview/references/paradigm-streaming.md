# Event Streaming Paradigm Reference

## What Are Event Streaming Platforms?

Event streaming platforms implement an **append-only, durable log** model: messages are written to an immutable, ordered log and retained for a configurable period. Consumers track their position (offset/cursor) independently and can replay from any point. Multiple consumer groups read the same data independently without interference.

**Examples:** Apache Kafka, Apache Pulsar, NATS JetStream

## Architecture Model

```
Traditional Broker:
  Producer --> [Broker buffers] --> Consumer (message deleted after ack)

Streaming Platform:
  Producer --> [Immutable Log] --> Consumer Group A (at offset 100)
                               --> Consumer Group B (at offset 50, replaying)
                               --> Consumer Group C (real-time, offset 150)
```

The fundamental difference: consuming does not destroy the message. Multiple independent consumers read the same log at their own pace.

## When to Use Event Streaming

### Strong Fit

- **Event sourcing and audit logs:** The append-only log is a natural event store. Every event is preserved for replay and temporal queries.
- **High-throughput data pipelines:** Millions of messages per second with sustained throughput. CDC pipelines, log aggregation, metrics collection.
- **Stream processing:** Windowed aggregations, stream joins, real-time analytics (Kafka Streams, Flink, Spark Streaming).
- **Multiple independent consumers:** Different teams or services consume the same event stream at their own pace without coordination.
- **Replay and reprocessing:** Fix a bug, deploy new logic, and replay from a point in time. Not possible with traditional brokers.
- **Long-term event retention:** Days, weeks, or months of retention with tiered storage offloading cold data to object storage.

### Weak Fit

- **Simple task queues:** If you just need competing consumers with message deletion after processing, a traditional broker (SQS, RabbitMQ) is simpler.
- **Complex message routing:** Streaming platforms route by topic only. No content-based routing, headers exchange, or filter rules at the broker level.
- **Low-volume, low-ops environments:** Running a Kafka cluster for 100 messages per day is overkill. Use a managed queue service.
- **Request/reply patterns:** Streaming platforms are optimized for unidirectional event flow, not synchronous request/response.

## Platform Comparison

### Apache Kafka

**Architecture:** Brokers store data on local disk. Topics are divided into partitions distributed across brokers. KRaft consensus (4.0+) manages metadata.

**Strengths:**
- Largest ecosystem: Kafka Connect (200+ connectors), Kafka Streams, ksqlDB, Schema Registry
- Exactly-once semantics (idempotent producer + transactions + read_committed)
- KRaft removes ZooKeeper dependency (4.0+), supports millions of partitions
- Tiered storage (3.9+) offloads cold segments to S3/GCS/Azure Blob
- Share Groups (4.2 GA) add queue-style semantics for non-ordered workloads
- Massive community, extensive tooling, mature operational practices

**Weaknesses:**
- Storage coupled to brokers: adding/removing brokers requires partition rebalancing
- Partition count is a critical design decision and hard to change later
- Operational complexity (even with KRaft): rolling upgrades, partition reassignment, ISR management
- No native multi-tenancy (namespace isolation only)
- No native geo-replication (MirrorMaker 2 is operationally complex)

### Apache Pulsar

**Architecture:** Stateless brokers serve requests. BookKeeper (bookies) provides durable storage. Metadata in ZooKeeper/etcd/Oxia. Serving and storage scale independently.

**Strengths:**
- Decoupled compute and storage: add brokers without data rebalancing, zero-copy failover
- Native multi-tenancy: tenant/namespace/topic hierarchy with resource isolation
- Native geo-replication: built-in async and sync replication across clusters
- Four subscription types: Exclusive, Shared, Failover, Key_Shared -- covers both streaming and queuing patterns natively
- Tiered storage built-in: offload sealed ledgers to S3/GCS/Azure Blob with erasure coding
- End-to-end encryption: broker never sees plaintext (unique among streaming platforms)
- Pulsar Functions: serverless compute for lightweight stream processing
- Kafka compatibility via KoP (Kafka-on-Pulsar) protocol handler

**Weaknesses:**
- Smaller ecosystem than Kafka (fewer connectors, less tooling)
- Higher operational complexity: three systems to manage (brokers, BookKeeper, metadata store)
- BookKeeper tuning is critical for performance (journal disks, entry logs, garbage collection)
- Community smaller than Kafka; fewer production deployment references

### NATS JetStream

**Architecture:** Single `nats-server` binary with JetStream enabled. Persistence via RAFT-replicated file or memory storage. No external dependencies.

**Strengths:**
- Single binary, zero external dependencies -- simplest operational model
- Sub-millisecond latency at scale (millions of messages per second on Core NATS)
- Built-in KV Store and Object Store on top of JetStream
- Leaf nodes for edge/IoT/hybrid deployments (hub-and-spoke topology)
- Stream mirrors and sources for geographic distribution
- Decentralized security model (operator/account/user JWTs)
- Lightweight resource footprint (suitable for edge and embedded)

**Weaknesses:**
- Smaller ecosystem than Kafka (no equivalent of Kafka Connect or ksqlDB)
- JetStream is younger than Kafka -- fewer production references at very large scale
- No native consumer group rebalancing protocol (queue groups work differently)
- Limited connector ecosystem

## Key Concepts

### Partitioning and Parallelism

Partitions (Kafka/Pulsar) or subjects (NATS) are the unit of parallelism. More partitions allow more concurrent consumers but increase metadata overhead.

| Platform | Parallelism Unit | Consumer Assignment |
|---|---|---|
| Kafka | Partition | One consumer per partition per group (classic); Share Groups for queue semantics (4.2+) |
| Pulsar | Partition | Depends on subscription type (Exclusive: 1, Shared: round-robin, Key_Shared: per-key) |
| NATS JetStream | Subject | Pull consumers with queue group semantics |

### Consumer Groups / Subscriptions

Multiple consumers cooperate to process a topic in parallel. Each message is delivered to exactly one consumer within the group.

- **Kafka:** Consumer group with partition assignment. Group coordinator manages rebalancing.
- **Pulsar:** Named subscription with type (Shared, Key_Shared, Failover, Exclusive).
- **NATS JetStream:** Durable pull consumer with multiple clients pulling from the same consumer.

### Offset / Cursor Management

Consumers track their position in the log:

- **Kafka:** Offsets committed to `__consumer_offsets` internal topic. Manual or auto commit.
- **Pulsar:** Cursor tracked per subscription in managed ledger. Individual or cumulative ack.
- **NATS JetStream:** Consumer tracks acknowledged sequence numbers. Explicit ack per message.

### Retention and Compaction

| Feature | Kafka | Pulsar | NATS JetStream |
|---|---|---|---|
| Time-based retention | `retention.ms` | Namespace `retention` policy | Stream `MaxAge` |
| Size-based retention | `retention.bytes` | Namespace `retention` policy | Stream `MaxBytes` |
| Log compaction | `cleanup.policy=compact` | Topic compaction | Not natively supported |
| Tiered storage | 3.9+ (S3, GCS, Azure) | Built-in (S3, GCS, Azure, MinIO) | Not supported |

### Exactly-Once Semantics

| Platform | Mechanism |
|---|---|
| Kafka | Idempotent producer (PID + sequence) + transactions + `read_committed` consumers |
| Pulsar | Producer deduplication (sequence ID) + transactions |
| NATS JetStream | `Nats-Msg-Id` header deduplication + `AckSync()` |

## Selection Guidance

| Criterion | Kafka | Pulsar | NATS JetStream |
|---|---|---|---|
| Ecosystem maturity | Largest | Growing | Smallest |
| Operational simplicity | Medium (KRaft helps) | Complex (3 systems) | Simplest (single binary) |
| Multi-tenancy | Weak | Native | Account-based |
| Geo-replication | MirrorMaker 2 | Native built-in | Mirrors + Sources |
| Latency | Low ms | Sub-ms possible | Sub-ms |
| Tiered storage | Plugin (3.9+) | Native | Not available |
| Queue semantics | Share Groups (4.2+) | Shared subscription | Queue groups |
| Edge/IoT | Not suited | Not suited | Leaf nodes (excellent) |
| Managed options | Confluent, MSK, Aiven | StreamNative, Aiven | Synadia Cloud |
| Kafka compatibility | Native | KoP protocol handler | Not available |

## Paradigm Decision Summary

```
Short-lived task queues, work distribution:
  --> Traditional broker (RabbitMQ, SQS, Service Bus)

Event sourcing, audit log, replay required:
  --> Streaming platform (Kafka, Pulsar)

Stream processing, temporal joins, aggregations:
  --> Kafka + Kafka Streams/Flink/Spark Streaming

Ultra-low latency, edge/IoT, microservice mesh:
  --> NATS (Core for fire-and-forget, JetStream for persistence)

Multi-tenant, geo-replicated enterprise streaming:
  --> Pulsar

Maximum ecosystem, connectors, community:
  --> Kafka

Hybrid (task queue + streaming):
  --> Kafka/Pulsar for streaming, SQS/Service Bus for task queues
  --> Or Pulsar (supports both natively via Shared subscriptions)
```
