---
name: messaging-kafka
description: "Cross-reference routing agent for Apache Kafka within the messaging domain. Routes to the primary Kafka agent in the ETL/streaming domain while providing messaging-specific context for Kafka as a pub/sub and event streaming platform. WHEN: \"Kafka messaging\", \"Kafka pub/sub\", \"Kafka queue\", \"Kafka event-driven\", \"Kafka Share Groups\", \"Kafka vs RabbitMQ\", \"Kafka vs Pulsar\", \"Kafka vs NATS\", \"Kafka consumer group messaging\"."
author: christopher huffman
license: MIT
metadata:
  version: "1.0.0"
---

# Apache Kafka — Messaging Domain Cross-Reference

This is a routing agent. The primary Kafka expert lives at `skills/etl/streaming/kafka/SKILL.md` and covers all Kafka topics in depth: broker architecture, KRaft consensus, producer/consumer patterns, Kafka Connect, Kafka Streams, Schema Registry, exactly-once semantics, tiered storage, and operational troubleshooting.

## When to Route to the Primary Kafka Agent

**Always route to `skills/etl/streaming/kafka/SKILL.md`** for:
- Kafka broker architecture, KRaft, ZooKeeper migration
- Producer and consumer configuration and tuning
- Kafka Connect (source/sink connectors, SMTs, DLQ)
- Kafka Streams (topology, state stores, windowing, joins)
- Schema Registry (Avro, Protobuf, compatibility modes)
- Exactly-once semantics (idempotent producer, transactions, read_committed)
- Tiered storage, log compaction, retention policies
- Security (SASL, mTLS, ACLs, OAUTHBEARER)
- Multi-datacenter replication (MirrorMaker 2)
- Monitoring (JMX metrics, consumer lag, broker health)
- CLI tools (kafka-topics.sh, kafka-consumer-groups.sh, kafka-configs.sh)
- Version-specific features (3.9, 4.0, 4.1, 4.2)

## Messaging-Specific Context for Kafka

When the question is about Kafka in a **messaging context** (not ETL/data integration), provide this additional framing before routing:

### Kafka as a Message Broker

Kafka is primarily an event streaming platform, but it can serve messaging use cases:

- **Pub/sub:** Multiple consumer groups on the same topic provide independent message delivery to each group.
- **Work queues:** Consumer groups distribute partitions across consumers. Each partition is processed by exactly one consumer in the group (classic protocol). Share Groups (4.2 GA) provide queue-like semantics where any consumer can process any message without partition binding.
- **Request/reply:** Not native. Requires application-level correlation ID management with dedicated reply topics.
- **Message ordering:** Per-partition ordering. Use partition key to route related messages to the same partition.

### Kafka vs Traditional Brokers (Messaging Perspective)

| Dimension | Kafka | Traditional Brokers (RabbitMQ, SQS, Service Bus) |
|---|---|---|
| Message lifecycle | Retained in log (offset-based) | Deleted after acknowledgment |
| Replay | Yes (seek to offset/timestamp) | No (except RabbitMQ streams) |
| Routing flexibility | Topic-based only | Exchange/filter/subscription-based |
| Message priority | Not supported | Supported (RabbitMQ, Service Bus) |
| Delayed delivery | Not native | Supported (SQS, Service Bus, RabbitMQ plugin) |
| Queue semantics | Share Groups (4.2+) | Native |
| Throughput | Very high (millions/s) | Medium (thousands to hundreds of thousands/s) |
| Operational complexity | Higher | Lower (especially managed services) |

### Share Groups (Kafka 4.2 GA) -- Queue Semantics

Share Groups provide traditional queue semantics on Kafka topics:
- Messages are delivered to any consumer in the group (not bound to partitions)
- Supports per-message acknowledgment
- Enables more consumers than partitions
- Use for workloads that do not require ordering
- GA in Kafka 4.2; preview in 4.1; EA in 4.0

### When to Choose Kafka for Messaging

**Choose Kafka when:**
- You need event replay and long-term retention
- Multiple independent consumer groups need the same data
- High throughput (millions of messages/s) is required
- You need stream processing (Kafka Streams, Flink)
- You already have Kafka infrastructure for ETL/streaming

**Choose a traditional broker when:**
- You need complex message routing (content-based, headers, filters)
- You need message priority, delayed delivery, or request/reply
- You need simple work queues with message deletion after processing
- You want zero-ops managed infrastructure (SQS, Service Bus)
- Message volume is low to moderate

## Cross-References

- **Primary agent:** `skills/etl/streaming/kafka/SKILL.md` -- Full Kafka expertise
- **Version agents:** `skills/etl/streaming/kafka/3.9/`, `4.0/`, `4.1/`, `4.2/` -- Version-specific features
- **Parent domain:** `../SKILL.md` -- Messaging domain routing and cross-broker comparisons
- **Pulsar comparison:** `../pulsar/SKILL.md` -- Alternative streaming platform
