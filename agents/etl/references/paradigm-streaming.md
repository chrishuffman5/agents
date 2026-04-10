# Paradigm: Streaming / Real-Time Data Integration

When and why to choose streaming tools for data pipelines. This file covers the paradigm itself, not specific engines -- see technology agents for engine-specific guidance.

## Choose Streaming When

- **Latency requirements are sub-minute.** Fraud detection, real-time dashboards, IoT sensor processing, live recommendations -- when batch latency is a business problem, not just a convenience issue.
- **The data model is event-driven.** Domain events (OrderPlaced, PaymentProcessed, InventoryUpdated) that multiple consumers need independently. Streaming decouples producers from consumers.
- **Change Data Capture is the source.** Log-based CDC (Debezium) produces a stream of database changes. Streaming infrastructure (Kafka) distributes these changes to multiple downstream consumers without repeated source queries.
- **Continuous processing is more efficient than repeated batch.** When batch jobs run so frequently (every 1-5 minutes) that they overlap or waste resources re-scanning unchanged data, a continuous streaming job is more efficient.
- **Event ordering and replay matter.** Kafka's partitioned log provides ordered, durable, replayable events. Consumers can rewind to reprocess from any offset.

## Avoid Streaming When

- **Hourly or daily latency is acceptable.** Streaming infrastructure is always-on and operationally complex. If daily batch loads meet the SLA, batch is simpler and cheaper.
- **The team lacks distributed systems experience.** Streaming requires understanding partitioning, consumer groups, offset management, backpressure, watermarks, and exactly-once semantics. The learning curve is steep.
- **Data volume is low.** Kafka's value proposition is high-throughput, durable event streaming. For a few thousand events per hour, a simple message queue (SQS, RabbitMQ) or webhook-based integration is sufficient.
- **Transformations are complex and stateful.** Streaming joins, windowed aggregations, and session tracking are significantly harder to implement and debug than their batch SQL equivalents. If the transformation is complex, consider streaming to a staging area and batch-transforming from there.

## Technology Landscape

| Tool | Category | Best For |
|---|---|---|
| **Apache Kafka** | Distributed event log | High-throughput event streaming, CDC distribution, durable replay |
| **Kafka Connect** | Source/sink connectors | Declarative data movement to/from Kafka without code |
| **Kafka Streams** | Stream processing library | Lightweight stateful processing within JVM applications |
| **Apache Flink** | Stream processing engine | Complex event processing, exactly-once, windowed aggregations |
| **Spark Structured Streaming** | Micro-batch / continuous | Batch+streaming unified API, existing Spark investment |
| **Amazon Kinesis** | Managed event log | AWS-native streaming, lower operational overhead than Kafka |
| **Azure Event Hubs** | Managed event log | Azure-native, Kafka-compatible API, tight Azure integration |

## Common Patterns

1. **CDC-to-Kafka-to-warehouse**: Debezium captures database changes into Kafka topics. Kafka Connect (JDBC Sink or warehouse-specific connector) loads changes into the analytics warehouse. Near-real-time replication without impacting source.
2. **Event sourcing**: Every state change is stored as an immutable event in Kafka. Current state is derived by replaying events. Enables audit trails, temporal queries, and independent consumer projections.
3. **Stream-table join**: Enrich a streaming event (e.g., order placed) with a slowly-changing lookup table (e.g., product catalog). Kafka Streams KTable or Flink's temporal table join.
4. **Dead letter topic**: Route malformed or unprocessable messages to a separate Kafka topic. Process or investigate them independently without blocking the main consumer.

## Anti-Patterns

1. **Streaming for everything** -- Not every data movement needs sub-second latency. Streaming adds operational complexity (always-on infra, partition management, offset tracking). Use batch unless latency is a genuine requirement.
2. **Unbounded state in stream processors** -- Kafka Streams or Flink state stores that grow indefinitely because windows are never closed or TTLs are not set. Eventually causes out-of-memory failures.
3. **Ignoring consumer lag** -- Consumer lag (offset behind the latest produced message) is the single most important streaming metric. Unmonitored lag leads to stale data, memory pressure, and silent data loss when retention expires.
4. **Single partition topics** -- All messages in one partition means one consumer thread. Throughput is capped at a single consumer's processing speed. Partition by a business key for parallelism.

## Decision Criteria

**Choose Kafka when:**
- High-throughput, durable, ordered event streaming is the core requirement
- Multiple consumers need independent access to the same event stream
- Replay capability (reprocess from any offset) is important
- The organization has (or is willing to invest in) Kafka operational expertise
- Managed options (Confluent Cloud, Amazon MSK, Azure Event Hubs with Kafka API) reduce operational burden

**Choose Kafka Connect when:**
- Declarative, connector-based data movement to/from Kafka is sufficient
- Standard sources (databases via Debezium, files, S3) and sinks (JDBC, Elasticsearch, warehouse) are involved
- No custom processing logic is needed between source and sink

**Choose micro-batch (Spark Structured Streaming) when:**
- Team already uses Spark for batch processing
- Latency of 1-10 seconds is acceptable (not true sub-second)
- Unified batch + streaming API simplifies the codebase
- Complex stateful transformations need Spark's SQL optimizer and DataFrame API

## Streaming Delivery Semantics

| Guarantee | Meaning | Implementation Cost | When Acceptable |
|---|---|---|---|
| **At-most-once** | Messages may be lost, never duplicated | Lowest (fire-and-forget) | Metrics, logging, non-critical telemetry |
| **At-least-once** | Messages never lost, may be duplicated | Medium (ack + retry) | Most pipelines (pair with idempotent sink) |
| **Exactly-once** | Messages never lost, never duplicated | Highest (transactions) | Financial, inventory, billing (when correctness is critical) |

Kafka supports exactly-once via idempotent producers + transactional consumers + transactional writes to the sink. In practice, at-least-once with an idempotent target (MERGE/upsert) is simpler and achieves effectively-exactly-once results.

## Key Metrics for Streaming Pipelines

| Metric | What It Tells You | Alert Threshold |
|---|---|---|
| **Consumer lag** | How far behind the consumer is from the latest produced offset | Growing lag (not recovering within minutes) |
| **Throughput (messages/sec)** | Processing rate vs production rate | Sustained consumption < production rate |
| **Processing latency** | Time from message production to consumption | > SLA threshold (e.g., > 5 seconds for real-time) |
| **Error rate** | Percentage of messages routed to dead letter topic | > 1% of messages failing |
| **Partition skew** | Uneven distribution across partitions | Any partition handling > 3x average load |

## Streaming vs Micro-Batch Decision

Some teams default to Spark Structured Streaming as a "streaming" solution. It is micro-batch by default (continuous mode is experimental). True sub-second latency requires native Kafka consumers, Kafka Streams, or Flink. Choose Spark Structured Streaming when the team already uses Spark and seconds-level latency is acceptable; choose Kafka Streams or Flink when millisecond-level latency or complex event processing is required.
