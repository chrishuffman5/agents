---
name: kafka
description: "Expert coverage of Apache Kafka as a messaging platform: broker architecture and operations, consumer-group mechanics, pub/sub and work-queue patterns, Share Groups, and Kafka-vs-traditional-broker trade-offs. Use for \"Kafka messaging\", \"Kafka pub/sub\", \"Kafka queue\", \"Kafka event-driven\", \"Kafka Share Groups\", \"Kafka vs RabbitMQ\", \"Kafka vs Pulsar\", \"Kafka vs NATS\", \"Kafka consumer group messaging\", \"consumer lag\", \"under-replicated partitions\", \"topic config\". Do NOT use for Kafka as a data-pipeline or stream-processing tool (Kafka Connect, Kafka Streams, CDC, ETL usage) -- that's the `kafka` skill in the `etl` plugin."
license: MIT
---

# Apache Kafka

This skill covers Apache Kafka from a messaging-platform angle: broker architecture, consumer-group mechanics, and how Kafka's log-based model maps onto pub/sub, work-queue, and event-driven patterns. For Kafka as a data-integration or stream-processing tool (Connect, Streams, CDC pipelines, Schema Registry-driven ETL), read the `kafka` skill in the `etl` plugin instead.

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

- The `kafka` skill in the `etl` plugin -- Kafka Connect, Kafka Streams, Schema Registry, CDC pipelines, and version-specific features (3.9, 4.0, 4.1, 4.2)
- The `overview` skill -- messaging domain cross-broker comparisons
- The `pulsar` skill -- alternative streaming platform

## Diagnostic Scripts

Ready-made CLI bundles (Kafka distribution tools; add --command-config for SASL/TLS) in `scripts/`, numbered by investigation order. All read-only.

- `scripts/01-consumer-lag.sh` -- Lag across all consumer groups with dead-consumer detection
- `scripts/02-under-replicated.sh` -- URP / under-min-ISR / offline partition triage (fix order included)
- `scripts/03-topic-config-audit.sh` -- RF vs min.insync sanity, retention overrides, partition ceilings
