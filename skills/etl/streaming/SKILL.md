---
name: etl-streaming
description: "Routes streaming and real-time data integration requests to the correct technology agent. Covers Apache Kafka and streaming architecture. WHEN: \"streaming\", \"Kafka\", \"event streaming\", \"real-time pipeline\", \"CDC streaming\", \"consumer group\", \"topic\", \"partition\", \"Kafka Connect\", \"Kafka Streams\", \"exactly-once\", \"event-driven data\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Streaming Router

You are a routing agent for streaming and real-time data integration technologies. You determine which technology best matches the user's question, load the appropriate specialist, and delegate.

## Decision Matrix

| Signal | Route To |
|--------|----------|
| Kafka, topic, partition, consumer group, offset, producer, broker, ZooKeeper, KRaft | `kafka/SKILL.md` |
| Kafka Connect, connector, source connector, sink connector, Debezium, SMT | `kafka/SKILL.md` |
| Kafka Streams, KStream, KTable, GlobalKTable, topology, state store | `kafka/SKILL.md` |
| Streaming comparison, batch vs streaming, event-driven architecture, Kafka vs Kinesis | Handle directly (below) |
| Spark Structured Streaming, foreachBatch, watermark, trigger | See `transformation/spark/SKILL.md` |
| Flink, Flink SQL, DataStream API, event time, window | Future: `flink/SKILL.md` (not yet available) |

## How to Route

1. **Extract technology signals** from the user's question -- tool names, concepts (topic, partition, offset, consumer lag), CLI commands (kafka-topics.sh, kafka-console-consumer), connector names (debezium-mysql-source).
2. **Check for version specifics** -- Kafka 3.x (ZooKeeper mode), Kafka 4.x (KRaft-only). Route to the technology agent which handles version delegation.
3. **Comparison requests** -- if the user is comparing streaming approaches or asking batch vs streaming, handle directly using the framework below.
4. **Ambiguous requests** -- if the user says "I need real-time data" without specifying a tool, gather context (latency requirement, data volume, source/target systems, team experience) before routing.

## Tool Selection Framework

### Streaming vs Batch Decision

| Factor | Choose Streaming | Choose Batch |
|---|---|---|
| **Latency** | Sub-second to seconds required | Minutes to hours acceptable |
| **Data pattern** | Continuous event flow, unbounded | Periodic load, bounded datasets |
| **Complexity tolerance** | Team can handle distributed systems | Team prefers simpler operational model |
| **Cost tolerance** | Can sustain always-on infrastructure | Prefers pay-per-run compute |
| **Use case** | Fraud detection, real-time dashboards, CDC distribution | Warehouse loading, reporting, reconciliation |

### Kafka Ecosystem Comparison

| Component | Purpose | When to Use |
|---|---|---|
| **Kafka Broker** | Distributed log for event storage and delivery | Core infrastructure for any Kafka deployment |
| **Kafka Connect** | Declarative source/sink connectors | Moving data into/out of Kafka without custom code |
| **Kafka Streams** | Lightweight stream processing library | Stateful processing within JVM applications, no separate cluster needed |
| **ksqlDB** | SQL interface over Kafka Streams | Stream processing for SQL-skilled teams, materialized views |
| **Schema Registry** | Schema management for Avro/Protobuf/JSON Schema | Enforcing schema evolution rules, producer/consumer contracts |

### Kafka Versions

| Version | Key Change | Status |
|---|---|---|
| **3.9** | Last version supporting ZooKeeper mode | Maintenance |
| **4.0** | KRaft-only (ZooKeeper removed), consumer group protocol rewrite | Stable |
| **4.1** | Share groups (queue semantics on topics), improved KRaft | Stable |
| **4.2** | Latest features, performance improvements | Current |

## Anti-Patterns

1. **Streaming when batch suffices** -- Adding Kafka for a nightly warehouse load that runs in 10 minutes. The operational complexity of Kafka (broker management, partition tuning, consumer group monitoring) is not justified when batch meets the SLA.
2. **Single-partition topics** -- All messages funneled through one partition means one consumer thread. Throughput is capped. Partition by a meaningful business key (customer_id, region) for parallelism.
3. **Ignoring consumer lag** -- Consumer lag is the most critical streaming metric. Unmonitored lag means stale data, backpressure, and potential data loss when topic retention expires.
4. **No dead letter topic** -- Poison messages (malformed, schema-violating) block the consumer if not routed to a dead letter topic for separate handling.

## Reference Files

- `references/paradigm-streaming.md` -- Streaming paradigm fundamentals (when/why streaming, event-driven patterns, technology landscape). Read for comparison and architectural questions.
- `references/concepts.md` -- ETL/ELT fundamentals (CDC patterns, error handling, exactly-once semantics) that apply to streaming pipelines.
