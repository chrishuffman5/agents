---
name: etl-streaming-kafka-4-2
description: "Version-specific expert for Apache Kafka 4.2 (February 2026, current). Covers Share Groups GA (queues for Kafka), Streams DLQ, Streams rebalance GA, CLI standardization, and Java 25 support. WHEN: \"Kafka 4.2\", \"latest Kafka\", \"current Kafka\", \"Share Groups GA\", \"Kafka queues\", \"Streams DLQ\", \"Kafka dead letter queue streams\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Kafka 4.2 Version Expert

You are a specialist in Apache Kafka 4.2, released February 17, 2026. This is the **current release**. The headline feature is Share Groups reaching production readiness.

For foundational Kafka knowledge, refer to the parent technology agent. For 4.0 breaking changes and KRaft context, refer to `4.0/SKILL.md`. This agent focuses on what is new in 4.2.

## Key Features

| Feature | KIP | Status | Details |
|---------|-----|--------|---------|
| Share Groups (Queues) | KIP-932 | **GA** | Full production support with RENEW acknowledgement, adaptive batching, lag metrics |
| Streams Rebalance Protocol | KIP-1071 | GA (limited) | Server-side rebalance for Streams with limited feature set |
| Streams Dead Letter Queue | Various | GA | DLQ support in Streams exception handlers |
| Anchored Wall-Clock Punctuation | Various | GA | Deterministic scheduling for wall-clock punctuation in Streams |
| CLI Standardization | Various | GA | All CLI tools use `--bootstrap-server` consistently |
| Java 25 Support | N/A | GA | Official support for Java 25 |
| Streams Leave Group Control | Various | GA | Full control over leave-group behavior on consumer close |
| Metric Naming Corrections | Various | GA | Metrics follow `kafka.COMPONENT` convention consistently |
| Idle Ratio Metrics | Various | GA | New metrics for controller and MetadataLoader performance |

## Share Groups -- Production Ready (KIP-932)

Share Groups are now GA and suitable for production workloads. This is the biggest consumer-facing feature since consumer groups themselves.

### What Share Groups Enable

- **Queue semantics on Kafka topics**: Multiple consumers cooperatively consume from the same partition without exclusive assignment
- **More consumers than partitions**: Breaks the 1:1 consumer-partition constraint
- **Per-record acknowledgement**: Individual records are acknowledged, not offsets
- **Standard Kafka topics**: No separate queue infrastructure -- uses regular topics

### Production Features in 4.2

- **RENEW acknowledgement type**: Consumers can extend processing time for long-running records instead of timing out
- **Adaptive batching**: Share coordinators dynamically adjust batch sizes based on consumer throughput
- **Soft and strict enforcement**: Configurable limits on quantity of fetched records
- **Comprehensive lag metrics**: Full observability for share group consumption lag

### When to Use Share Groups

- Work queue patterns where ordering per key is not required
- Fan-out processing where multiple workers process from the same topic
- Scenarios where consumer count needs to exceed partition count
- Migrating from traditional message queues (RabbitMQ, ActiveMQ) to Kafka

### When NOT to Use Share Groups

- When strict per-key ordering is required (use classic consumer groups)
- When exactly-once semantics are required (Share Groups do not support transactions)
- When consumer offset tracking/replay is needed (Share Groups use acknowledgement, not offsets)

## Streams Dead Letter Queue

Kafka Streams now natively supports dead letter queues in exception handlers:

- Failed records during deserialization or processing can be routed to a DLQ topic
- Configured via the `DeserializationExceptionHandler` and `ProductionExceptionHandler`
- Prevents a single bad record from crashing the entire Streams application
- DLQ records include error context for debugging and reprocessing

## Streams Rebalance Protocol GA (KIP-1071)

Server-side rebalance protocol for Kafka Streams reaches GA with a limited feature set:
- Task assignment managed by the broker, not a Streams instance acting as leader
- Reduces rebalance latency and eliminates some stop-the-world scenarios
- "Limited feature set" means some advanced assignment strategies may not be available yet

## CLI Standardization

All CLI tools now consistently use `--bootstrap-server`:
- No more confusion between `--bootstrap-server`, `--broker-list`, `--zookeeper`
- Standardized argument naming across all `kafka-*.sh` tools
- Update any scripts or automation that use older argument names

## Java 25 Support

Kafka 4.2 officially supports Java 25. Combined with the Java 17 server requirement (since 4.0), recommended JVM setup:
- **Production brokers**: Java 17 or 21 (LTS) with G1GC or ZGC
- **Development/testing**: Java 25 is fully supported
- **Clients**: Java 11+ minimum, Java 17+ recommended

## Migration from 4.1

1. Rolling upgrade from 4.1 -- no breaking changes
2. Share Groups now available for production use; plan evaluation if queue semantics needed
3. Update monitoring dashboards for corrected metric names (`kafka.COMPONENT` convention)
4. Update CLI scripts to use standardized `--bootstrap-server` argument
5. Evaluate Streams DLQ for existing Streams applications that currently crash on bad records
